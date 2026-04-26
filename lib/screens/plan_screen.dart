import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/food_entry.dart';
import '../models/meal_idea.dart';
import '../models/planned_meal.dart';
import '../services/caliana_service.dart';
import '../services/day_log_service.dart';
import '../services/plan_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/week_status_strip.dart';

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
  String _activeMode = 'normal';
  final ImagePicker _imagePicker = ImagePicker();

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

    final showDamageControl = _shouldShowDamageControl();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _header(),
            const SizedBox(height: 18),
            const WeekStatusStrip(),
            const SizedBox(height: 14),
            if (showDamageControl) ...[
              _damageControlCard(),
              const SizedBox(height: 14),
            ],
            _tomorrowHeroCard(tomorrowMeals),
            const SizedBox(height: 14),
            _smartModesSection(),
            const SizedBox(height: 14),
            _fridgeRescueCard(),
            const SizedBox(height: 16),
            _upcomingSection(),
          ],
        ),
      ),
    );
  }

  bool _shouldShowDamageControl() {
    final profile = UserProfileService.instance.profile;
    final goal = profile.dailyCalorieGoal;
    final today = DayLogService.instance.today;
    final todayDelta = today.totalCalories - goal;
    final weeklyDelta =
        DayLogService.instance.weeklyCalories - goal * 7;
    return todayDelta > 200 || weeklyDelta > 600;
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
  // Damage Control — surfaces only when the user is over for today or
  // the week. Anti-restriction by design: never recommends fasting,
  // skipping meals, or compensating with exercise. Just calmly offers
  // the rebuild plan ready to apply.
  // ---------------------------------------------------------------------------
  Widget _damageControlCard() {
    final profile = UserProfileService.instance.profile;
    final goal = profile.dailyCalorieGoal;
    final today = DayLogService.instance.today;
    final todayDelta = today.totalCalories - goal;
    final weeklyDelta =
        DayLogService.instance.weeklyCalories - goal * 7;

    final String headline;
    final String body;
    final String ctaLabel;
    final String ctaMode;

    if (todayDelta > goal * 0.4) {
      // Today is gone — protect tomorrow.
      headline = "Today's gone. Don't crash.";
      body =
          "${todayDelta} over goal already. Tomorrow is a clean reset — high protein, normal calories, no punishment. Want me to lay it out?";
      ctaLabel = 'Plan tomorrow clean';
      ctaMode = 'recovery';
    } else if (todayDelta > 200) {
      // Today is salvageable.
      final left = goal - today.totalCalories;
      headline = "Bit over — still salvageable";
      body =
          "Slightly over today (${todayDelta} kcal). About ${left.abs()} room before bed if you go light. I can build a small dinner that lands you back.";
      ctaLabel = 'Build a light dinner';
      ctaMode = 'recovery';
    } else if (weeklyDelta > 1500) {
      headline = "Heavy week — proper rebuild";
      body =
          "$weeklyDelta over for the week. Three to four days, protein-led, normal calories. We absorb it — no crash, no shame.";
      ctaLabel = 'Build the rebuild';
      ctaMode = 'recovery';
    } else {
      headline = "Bit over this week — easy fix";
      final perDay = (weeklyDelta / 3).round();
      body =
          "$weeklyDelta over the week. Trim ~$perDay kcal across the next 3 days. Steady, not strict.";
      ctaLabel = 'Build the next 3 days';
      ctaMode = 'recovery';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1EC), Color(0xFFFFE4DA)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.30),
          width: 1,
        ),
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
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Text(
                  'DAMAGE CONTROL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textPrimary.withValues(alpha: 0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _primaryButton(
            label: _generating ? 'Building…' : ctaLabel,
            onTap: _generating ? null : () => _generatePlan(mode: ctaMode),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Modes — horizontal carousel of preset plan styles. Tap once,
  // tomorrow's plan regenerates in that mode.
  // ---------------------------------------------------------------------------
  Widget _smartModesSection() {
    const modes = [
      _ModeSpec(id: 'normal', label: 'Maintain', emoji: '⚖️',
          tag: 'Balanced', color: Color(0xFF2F6BFF)),
      _ModeSpec(id: 'high_protein', label: 'High protein', emoji: '🍗',
          tag: '30g+ per meal', color: Color(0xFFE94A6F)),
      _ModeSpec(id: 'recovery', label: 'Recovery', emoji: '🌿',
          tag: 'Lean reset', color: Color(0xFF22C55E)),
      _ModeSpec(id: 'cut', label: 'Cut', emoji: '🔥',
          tag: 'Volume + protein', color: Color(0xFFFF7A45)),
      _ModeSpec(id: 'cheap', label: 'Budget', emoji: '💷',
          tag: 'Real food, low spend', color: Color(0xFF8B5CF6)),
      _ModeSpec(id: 'busy', label: 'Busy', emoji: '⏱️',
          tag: '<20 min cook', color: Color(0xFF0EA5E9)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                'SMART MODES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textHint,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'one tap, fresh plan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: modes.length,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemBuilder: (context, i) {
              final m = modes[i];
              return Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 8,
                  right: i == modes.length - 1 ? 0 : 0,
                ),
                child: _ModeCard(
                  spec: m,
                  active: _activeMode == m.id,
                  onTap: () => _applyMode(m.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fridge Rescue — large CTA card. Snap or pick a fridge photo and
  // Caliana proposes meals that use what's in.
  // ---------------------------------------------------------------------------
  Widget _fridgeRescueCard() {
    return GestureDetector(
      onTap: _onFridgeRescue,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.kitchen_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fridge rescue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Snap what's in. I'll build meals from it that fit today.",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
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

  Future<void> _applyMode(String modeId) async {
    HapticFeedback.lightImpact();
    setState(() => _activeMode = modeId);
    await _generatePlan(mode: modeId);
  }

  Future<void> _onFridgeRescue() async {
    HapticFeedback.lightImpact();
    final source = await _pickPhotoSource(
      title: 'Show me your fridge',
    );
    if (source == null) return;
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _generating = true);
    try {
      final ideas =
          await CalianaService.instance.fridgeSuggest(picked.path);
      if (!mounted) return;
      if (ideas.isEmpty) {
        setState(() {
          _generating = false;
          _generateError =
              "Couldn't read the fridge. Try a brighter photo or pick from library.";
        });
        return;
      }
      // Drop the fridge ideas as the next 3 upcoming meals (today's
      // dinner / tomorrow lunch / tomorrow dinner). Lightweight; the
      // user commits whichever they actually cook.
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final targets = <(DateTime, String)>[
        (now, 'dinner'),
        (tomorrow, 'lunch'),
        (tomorrow, 'dinner'),
      ];
      for (var i = 0; i < ideas.length && i < targets.length; i++) {
        final (date, slot) = targets[i];
        final meal = PlannedMeal(
          id: 'pm_${DateTime.now().millisecondsSinceEpoch}_fridge_$i',
          date: date,
          slot: slot,
          idea: ideas[i],
        );
        await PlanService.instance.swapMeal(date, meal);
      }
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generateError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generateError = 'Fridge failed: $e';
      });
    }
  }

  Future<ImageSource?> _pickPhotoSource({required String title}) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _photoSourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take a photo',
                  onTap: () =>
                      Navigator.pop(sheetCtx, ImageSource.camera),
                ),
                const SizedBox(height: 8),
                _photoSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from library',
                  onTap: () =>
                      Navigator.pop(sheetCtx, ImageSource.gallery),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoSourceTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 22),
            ],
          ),
        ),
      ),
    );
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

// ============================================================================
// Smart Mode card spec + widget.
// ============================================================================
class _ModeSpec {
  final String id;
  final String label;
  final String emoji;
  final String tag;
  final Color color;
  const _ModeSpec({
    required this.id,
    required this.label,
    required this.emoji,
    required this.tag,
    required this.color,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeSpec spec;
  final bool active;
  final VoidCallback onTap;

  const _ModeCard({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 140,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? spec.color : AppColors.surfaceBorder,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: spec.color.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: spec.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(spec.emoji,
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.tag,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: spec.color,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
