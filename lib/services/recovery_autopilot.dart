import 'package:flutter/foundation.dart';
import 'caliana_service.dart';
import 'day_log_service.dart';
import 'plan_service.dart';
import 'user_profile_service.dart';
import '../models/planned_meal.dart';

/// Watches the day log and rebuilds tomorrow's plan in recovery mode
/// the moment today crosses a meaningful overage threshold. The whole
/// product promise:
///
///   "Live the day. I'll handle the calories."
///
/// is delivered HERE — the user logs a 2,000 kcal night out, this
/// service kicks in, generates tomorrow's plan with the absorbing
/// delta passed to the backend, and surfaces the change via the
/// existing PlanService.notifyListeners.
///
/// Rules to keep it from being annoying:
/// - Only fires once per day per overage bracket.
/// - Only fires when the user is at least 250 kcal over goal — small
///   slips don't need a whole rebuild.
/// - Skips if the user manually built a plan for tomorrow within the
///   last hour (don't clobber their choices).
class RecoveryAutopilot {
  RecoveryAutopilot._();
  static final RecoveryAutopilot instance = RecoveryAutopilot._();

  bool _started = false;
  String _lastFiredDateKey = '';
  int _lastFiredDelta = 0;

  /// Wire up listeners on app boot. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    DayLogService.instance.addListener(_onLogChange);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    DayLogService.instance.removeListener(_onLogChange);
  }

  Future<void> _onLogChange() async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final profile = UserProfileService.instance.profile;
    final goal = profile.dailyCalorieGoal;
    if (goal <= 0) return;
    final today = DayLogService.instance.today;
    final delta = today.totalCalories - goal;
    if (delta < 250) return; // Below threshold — small slips don't trigger.

    // Re-fire only when the bracket meaningfully grows. Once we've
    // built a plan absorbing 500 kcal, an extra 50 doesn't justify
    // another rebuild; +250 more (one extra "snack" worth of damage)
    // does.
    if (dateKey == _lastFiredDateKey && (delta - _lastFiredDelta) < 250) {
      return;
    }

    _lastFiredDateKey = dateKey;
    _lastFiredDelta = delta;

    // Don't overwrite a plan the user explicitly built/edited recently.
    // (We don't track edit timestamps yet; cheap heuristic: if any
    // committed meals exist on tomorrow, leave it alone — the user is
    // already executing the plan.)
    final tomorrow = now.add(const Duration(days: 1));
    final existing = PlanService.instance.forDay(tomorrow);
    final committedAny = existing.any((m) => m.committed);
    if (committedAny) return;

    debugPrint(
      '🔄 RecoveryAutopilot: today $delta over goal — rebuilding tomorrow.',
    );
    try {
      final ideas = await CalianaService.instance.generateDayPlan(
        mode: 'recovery',
        targetKcalOverride: goal - delta,
        absorbingDeltaKcal: delta,
      );
      if (ideas.isEmpty) return;
      final meals = ideas
          .map(
            (idea) => PlannedMeal(
              id: 'pm_${DateTime.now().millisecondsSinceEpoch}_${idea.description ?? ''}',
              date: tomorrow,
              slot: idea.description ?? 'snack',
              idea: idea,
            ),
          )
          .toList();
      await PlanService.instance.setDayPlan(tomorrow, meals);
    } catch (e) {
      debugPrint('🔄 RecoveryAutopilot rebuild failed: $e');
    }
  }
}
