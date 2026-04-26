import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_entry.dart';
import '../models/meal_idea.dart';
import '../models/planned_meal.dart';
import '../services/caliana_service.dart';
import '../services/day_log_service.dart';
import '../services/plan_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';

/// Plan tab — Caliana's "what should I eat next so I stay on track?"
/// answer screen. Three sections in V1:
///   - Tomorrow Plan (hero, 4 meal cards, kcal/protein targets)
///   - Weekly Reset (kcal over for the week + reset buttons)
///   - Upcoming Meals (planned meals with one-tap commit)
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _generating = false;
  String? _generateError;

  @override
  void initState() {
    super.initState();
    PlanService.instance.addListener(_onChange);
    DayLogService.instance.addListener(_onChange);
    UserProfileService.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    PlanService.instance.removeListener(_onChange);
    DayLogService.instance.removeListener(_onChange);
    UserProfileService.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  DateTime get _tomorrow =>
      DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final tomorrowMeals = PlanService.instance.forDay(_tomorrow);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _header(),
            const SizedBox(height: 18),
            _tomorrowHeroCard(tomorrowMeals),
            const SizedBox(height: 16),
            _weeklyResetCard(),
            const SizedBox(height: 16),
            _upcomingSection(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Plan',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.2,
                  height: 1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "What's next, sorted in advance.",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tomorrow Plan
  // ---------------------------------------------------------------------------

  Widget _tomorrowHeroCard(List<PlannedMeal> meals) {
    final profile = UserProfileService.instance.profile;
    final totalKcal = meals.fold<int>(0, (s, m) => s + m.idea.calories);
    final totalProtein =
        meals.fold<int>(0, (s, m) => s + m.idea.protein);
    final hasPlan = meals.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tomorrow',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPlan
                            ? '$totalKcal kcal · ${totalProtein}g P'
                            : '${profile.dailyCalorieGoal} kcal · ${profile.dailyProteinGrams}g P target',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasPlan)
                  GestureDetector(
                    onTap: _generating ? null : _generatePlan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        'Regenerate',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!hasPlan) _emptyPlanState() else _planMealsList(meals),
        ],
      ),
    );
  }

  Widget _emptyPlanState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No plan for tomorrow yet.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Caliana lines up breakfast, lunch, dinner and a snack — all single-portion, all hitting your kcal and protein targets.",
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_generateError != null) ...[
            const SizedBox(height: 10),
            Text(
              _generateError!,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _primaryButton(
            label: _generating ? 'Building plan…' : 'Use this plan',
            onTap: _generating ? null : _generatePlan,
          ),
        ],
      ),
    );
  }

  Widget _planMealsList(List<PlannedMeal> meals) {
    final ordered = [...meals]..sort((a, b) =>
        kMealSlots.indexOf(a.slot).compareTo(kMealSlots.indexOf(b.slot)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          for (final m in ordered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _PlanMealRow(
                planned: m,
                onSwap: () => _swapMeal(m),
                onDelete: () => _deleteMeal(m),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Weekly Reset
  // ---------------------------------------------------------------------------

  Widget _weeklyResetCard() {
    final profile = UserProfileService.instance.profile;
    final goal = profile.dailyCalorieGoal;
    final consumed = DayLogService.instance.weeklyCalories;
    final weekTarget = goal * 7;
    final delta = consumed - weekTarget;

    String headline;
    String subhead;
    if (delta <= 0) {
      headline = 'On track this week';
      subhead =
          "You're under by ${(-delta).abs()} kcal across 7 days. Keep doing what you're doing.";
    } else if (delta < 600) {
      headline = '${delta} kcal over this week';
      subhead =
          "Tight, but absorbable. Light tea two nights and you're square.";
    } else if (delta < 1500) {
      headline = '${delta} kcal over this week';
      final perDay = (delta / 3).round();
      subhead =
          "Easy correction. Trim ${perDay} kcal across the next 3 days, no crash.";
    } else {
      headline = '${delta} kcal over this week';
      subhead =
          "Heavy. Don't crash. Reset over 3-4 days: high-protein, lighter carbs, normal calories.";
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: delta > 0
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : const Color(0xFF22C55E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'WEEKLY RESET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: delta > 0
                        ? AppColors.accent
                        : const Color(0xFF22C55E),
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subhead,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (delta > 600)
            _primaryButton(
              label: _generating ? 'Building reset…' : 'Build reset week',
              onTap: _generating ? null : () => _generatePlan(mode: 'recovery'),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Upcoming Meals
  // ---------------------------------------------------------------------------

  Widget _upcomingSection() {
    final upcoming = PlanService.instance.upcoming
        .where((m) => !m.committed)
        .take(8)
        .toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'UPCOMING MEALS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textHint,
              letterSpacing: 1.4,
            ),
          ),
        ),
        for (final m in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _UpcomingRow(
              planned: m,
              onCommit: () => _commitMeal(m),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _generatePlan({String mode = 'normal'}) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _generating = true;
      _generateError = null;
    });
    try {
      final ideas =
          await CalianaService.instance.generateDayPlan(mode: mode);
      if (!mounted) return;
      if (ideas.isEmpty) {
        setState(() {
          _generating = false;
          _generateError =
              "Couldn't reach Caliana's planner. Try again in a moment.";
        });
        return;
      }
      final tomorrow = _tomorrow;
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
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generateError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generateError = 'Plan failed: $e';
      });
    }
  }

  Future<void> _swapMeal(PlannedMeal current) async {
    HapticFeedback.lightImpact();
    // Single-slot regenerate: hit suggestMeals with a slot-shaped ask,
    // pick the top idea, replace this slot.
    final ask = '${current.slot} meal under ${current.idea.calories + 60} kcal that fits my macros';
    final ideas = await CalianaService.instance.suggestMeals(ask);
    if (!mounted) return;
    if (ideas.isEmpty) return;
    final pick = ideas.first;
    final replaced = current.copyWith(idea: pick);
    await PlanService.instance.swapMeal(current.date, replaced);
  }

  Future<void> _deleteMeal(PlannedMeal m) async {
    HapticFeedback.heavyImpact();
    await PlanService.instance.deleteMeal(m.date, m.id);
  }

  Future<void> _commitMeal(PlannedMeal m) async {
    HapticFeedback.mediumImpact();
    final entry = FoodEntry(
      id: 'fe_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: m.date,
      name: m.idea.name,
      calories: m.idea.calories,
      proteinGrams: m.idea.protein,
      carbsGrams: m.idea.carbs,
      fatGrams: m.idea.fat,
      inputMethod: 'plan',
      photoPath: null,
      confidence: 'high',
      notes: 'From Plan · ${slotLabel(m.slot)}',
    );
    await DayLogService.instance.addEntry(entry);
    await PlanService.instance.markCommitted(m.date, m.id);
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
                  )
                : null,
            color: enabled ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : Colors.grey.shade600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Inline meal row inside the Tomorrow Plan card.
// ============================================================================
class _PlanMealRow extends StatelessWidget {
  final PlannedMeal planned;
  final VoidCallback onSwap;
  final VoidCallback onDelete;

  const _PlanMealRow({
    required this.planned,
    required this.onSwap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final idea = planned.idea;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: idea.imageUrl != null && idea.imageUrl!.isNotEmpty
                  ? Image.network(
                      idea.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgFallback(),
                    )
                  : _imgFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slotLabel(planned.slot).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  idea.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${idea.calories} kcal · ${idea.protein}P / ${idea.carbs}C / ${idea.fat}F',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSwap,
            tooltip: 'Swap meal',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.10),
      child: const Icon(
        Icons.restaurant_rounded,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}

// ============================================================================
// Upcoming row — slim, with an "I ate this" commit button.
// ============================================================================
class _UpcomingRow extends StatelessWidget {
  final PlannedMeal planned;
  final VoidCallback onCommit;

  const _UpcomingRow({required this.planned, required this.onCommit});

  String _whenLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mealDay = DateTime(
      planned.date.year,
      planned.date.month,
      planned.date.day,
    );
    final diff = mealDay.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) {
      const wd = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return wd[(planned.date.weekday - 1) % 7];
    }
    return '${planned.date.day}/${planned.date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final idea = planned.idea;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _whenLabel(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textHint,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${slotLabel(planned.slot)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  idea.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${idea.calories} kcal · ${idea.protein}P',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCommit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'I ate this',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
