import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/usage_service.dart';
import '../services/analytics_service.dart';
import '../widgets/aurora_background.dart';
import '../widgets/character_card.dart';
import 'paywall_screen.dart';

/// Caliana's onboarding. 10 screens, ~90 sec.
/// Captures everything needed to compute calorie + macro goals, plus
/// Caliana's tone preference and the ED safety gate.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  static const _seenKey = 'caliana_onboarding_seen_v1';

  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _index = 0;

  // Draft profile being assembled across screens.
  UserProfile _draft = const UserProfile();

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    AnalyticsService.instance.logOnboardingStep(_index, _stepLabel(_index));
    HapticFeedback.mediumImpact();
    if (_index < 9) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_index == 0) return;
    HapticFeedback.lightImpact();
    _pc.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String _stepLabel(int i) => switch (i) {
        0 => 'welcome',
        1 => 'biometrics',
        2 => 'goal',
        3 => 'activity',
        4 => 'diet',
        5 => 'tone',
        6 => 'notifications',
        7 => 'plan_reveal',
        8 => 'social_proof',
        9 => 'paywall',
        _ => 'unknown',
      };

  Future<void> _finish() async {
    final completed = _draft.copyWith(onboardingComplete: true);
    await UserProfileService.instance.update(completed);
    AnalyticsService.instance.logOnboardingComplete(
      tone: completed.tone,
      goalType: completed.goalType,
      dailyKcal: completed.dailyCalorieGoal,
    );
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pc,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _Welcome(onNext: _next),
                    _Biometrics(
                      draft: _draft,
                      onUpdate: (p) => setState(() => _draft = p),
                      onNext: _next,
                    ),
                    _Goal(
                      draft: _draft,
                      onUpdate: (p) => setState(() => _draft = p),
                      onNext: _next,
                    ),
                    _Activity(
                      draft: _draft,
                      onUpdate: (p) => setState(() => _draft = p),
                      onNext: _next,
                    ),
                    _Diet(
                      draft: _draft,
                      onUpdate: (p) => setState(() => _draft = p),
                      onNext: _next,
                    ),
                    _Tone(
                      draft: _draft,
                      onUpdate: (p) => setState(() => _draft = p),
                      onNext: _next,
                    ),
                    _Notifications(
                      draft: _draft,
                      onUpdate: (p) => setState(() => _draft = p),
                      onNext: _next,
                    ),
                    _PlanReveal(draft: _draft, onNext: _next),
                    _SocialProof(onNext: _next),
                    _SoftPaywall(onContinueFree: _finish, onSubscribe: _finish),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          if (_index > 0)
            GestureDetector(
              onTap: _back,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + 1) / 10,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${_index + 1}/10',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 1 — Welcome
// ============================================================================
class _Welcome extends StatefulWidget {
  final VoidCallback onNext;
  const _Welcome({required this.onNext});

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  final AudioPlayer _intro = AudioPlayer();
  bool _played = false;

  @override
  void initState() {
    super.initState();
    // Auto-play the ElevenLabs intro once after first frame.
    // Fails silently if the asset isn't there yet.
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_played) return;
    _played = true;
    try {
      await _intro.stop();
      await _intro.play(AssetSource('audio/onboarding_intro.mp3'));
    } catch (_) {
      // Silent — the screen still works without audio.
    }
  }

  Future<void> _replay() async {
    HapticFeedback.lightImpact();
    _played = false;
    await _play();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Image.asset(
            'assets/caliana.png',
            width: 220,
            height: 220,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 18),
          const Text(
            'Caliana',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Calories, but make it British.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Half sharp mate, half narrator quietly\njudging your third coffee.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _replay,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hear Caliana',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 3),
          _PrimaryButton(label: 'Continue', onTap: widget.onNext),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 2 — Biometrics (sex, age, height, weight)
// ============================================================================
class _Biometrics extends StatefulWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onUpdate;
  final VoidCallback onNext;

  const _Biometrics({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<_Biometrics> createState() => _BiometricsState();
}

class _BiometricsState extends State<_Biometrics> {
  late String _sex = widget.draft.sex;
  late int _age = widget.draft.ageYears;
  late double _heightCm = widget.draft.heightCm;
  late double _weightKg = widget.draft.weightKg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('A bit about you'),
          const _Subtitle(
              'Caliana needs the basics to calculate your numbers.'),
          const SizedBox(height: 24),
          Text('Sex',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SegButton(
                  label: 'Female',
                  selected: _sex == 'female',
                  onTap: () => setState(() => _sex = 'female'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegButton(
                  label: 'Male',
                  selected: _sex == 'male',
                  onTap: () => setState(() => _sex = 'male'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegButton(
                  label: 'Other',
                  selected: _sex == 'other',
                  onTap: () => setState(() => _sex = 'other'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SliderRow(
            label: 'Age',
            value: _age.toDouble(),
            min: 14,
            max: 90,
            divisions: 76,
            display: '$_age yrs',
            onChanged: (v) => setState(() => _age = v.round()),
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'Height',
            value: _heightCm,
            min: 130,
            max: 220,
            divisions: 90,
            display: '${_heightCm.round()} cm',
            onChanged: (v) => setState(() => _heightCm = v),
          ),
          const SizedBox(height: 16),
          _SliderRow(
            label: 'Current weight',
            value: _weightKg,
            min: 35,
            max: 200,
            divisions: 165,
            display: '${_weightKg.toStringAsFixed(1)} kg',
            onChanged: (v) => setState(() => _weightKg = v),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              widget.onUpdate(widget.draft.copyWith(
                sex: _sex,
                ageYears: _age,
                heightCm: _heightCm,
                weightKg: _weightKg,
              ));
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 3 — Goal (lose / maintain / gain) + target weight
// ============================================================================
class _Goal extends StatefulWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onUpdate;
  final VoidCallback onNext;

  const _Goal({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<_Goal> createState() => _GoalState();
}

class _GoalState extends State<_Goal> {
  late String _goal = widget.draft.goalType;
  late double _target = widget.draft.weightKg;

  @override
  Widget build(BuildContext context) {
    final delta = _target - widget.draft.weightKg;
    final weeks = (delta.abs() / 0.45).ceil();
    final eta = weeks > 0
        ? DateTime.now().add(Duration(days: weeks * 7))
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('What\'s the mission?'),
          const _Subtitle('Caliana shapes your day around this.'),
          const SizedBox(height: 24),
          _GoalCard(
            emoji: '⬇️',
            title: 'Lose weight',
            sub: 'Sustainable cut — about a pound a week',
            selected: _goal == 'lose',
            onTap: () => setState(() {
              _goal = 'lose';
              if (_target >= widget.draft.weightKg) {
                _target = (widget.draft.weightKg - 5).clamp(35, 200);
              }
            }),
          ),
          const SizedBox(height: 10),
          _GoalCard(
            emoji: '⚖️',
            title: 'Maintain',
            sub: 'Hold steady — eat at maintenance',
            selected: _goal == 'maintain',
            onTap: () => setState(() {
              _goal = 'maintain';
              _target = widget.draft.weightKg;
            }),
          ),
          const SizedBox(height: 10),
          _GoalCard(
            emoji: '⬆️',
            title: 'Gain weight',
            sub: 'Lean bulk — slow, intentional gain',
            selected: _goal == 'gain',
            onTap: () => setState(() {
              _goal = 'gain';
              if (_target <= widget.draft.weightKg) {
                _target = (widget.draft.weightKg + 5).clamp(35, 200);
              }
            }),
          ),
          if (_goal != 'maintain') ...[
            const SizedBox(height: 22),
            _SliderRow(
              label: 'Target weight',
              value: _target,
              min: 35,
              max: 200,
              divisions: 165,
              display: '${_target.toStringAsFixed(1)} kg',
              onChanged: (v) => setState(() => _target = v),
            ),
            if (eta != null && delta.abs() > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: GlassDecoration.coralCard(opacity: 0.05),
                child: Text(
                  'Caliana reckons you\'ll hit it around '
                  '${_monthName(eta.month)} ${eta.day}, ${eta.year}.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              widget.onUpdate(widget.draft.copyWith(
                goalType: _goal,
                targetWeightKg: _target,
                targetDate: eta == null
                    ? null
                    : '${eta.year}-${eta.month.toString().padLeft(2, '0')}-${eta.day.toString().padLeft(2, '0')}',
              ));
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}

// ============================================================================
// SCREEN 4 — Activity level
// ============================================================================
class _Activity extends StatefulWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onUpdate;
  final VoidCallback onNext;

  const _Activity({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<_Activity> createState() => _ActivityState();
}

class _ActivityState extends State<_Activity> {
  late String _level = widget.draft.activityLevel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('How active are you?'),
          const _Subtitle('Be honest — Caliana can tell.'),
          const SizedBox(height: 24),
          ..._levels.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GoalCard(
                  emoji: opt['emoji']!,
                  title: opt['title']!,
                  sub: opt['sub']!,
                  selected: _level == opt['value'],
                  onTap: () => setState(() => _level = opt['value']!),
                ),
              )),
          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              widget.onUpdate(widget.draft.copyWith(activityLevel: _level));
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }

  static const _levels = [
    {
      'value': 'couch',
      'emoji': '🛋️',
      'title': 'Couch life',
      'sub': 'Desk job, no real exercise',
    },
    {
      'value': 'light',
      'emoji': '🚶',
      'title': 'Light',
      'sub': 'Walk a bit, gym 1–2 times a week',
    },
    {
      'value': 'active',
      'emoji': '🏃',
      'title': 'Active',
      'sub': 'Train 3–5 times a week',
    },
    {
      'value': 'athlete',
      'emoji': '🏋️',
      'title': 'Athlete',
      'sub': 'Daily training, manual job, or both',
    },
  ];
}

// ============================================================================
// SCREEN 5 — Diet & allergies
// ============================================================================
class _Diet extends StatefulWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onUpdate;
  final VoidCallback onNext;

  const _Diet({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<_Diet> createState() => _DietState();
}

class _DietState extends State<_Diet> {
  late String _diet = widget.draft.dietaryStyle;
  late final List<String> _allergies = List.from(widget.draft.allergies);

  static const _diets = [
    'none', 'vegetarian', 'vegan', 'pescatarian', 'keto', 'paleo',
    'gluten-free', 'halal',
  ];
  static const _common = [
    'Gluten', 'Dairy', 'Nuts', 'Peanuts', 'Shellfish', 'Eggs', 'Soy', 'Fish',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Diet & allergies'),
          const _Subtitle('So Caliana never suggests something you can\'t eat.'),
          const SizedBox(height: 18),
          Text('Diet', style: _labelStyle()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _diets
                .map((d) => _PillChip(
                      label: d == 'none' ? 'No restriction' : d,
                      selected: _diet == d,
                      onTap: () => setState(() => _diet = d),
                    ))
                .toList(),
          ),
          const SizedBox(height: 22),
          Text('Allergies (multi)', style: _labelStyle()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _common
                .map((a) => _PillChip(
                      label: a,
                      selected: _allergies.contains(a),
                      onTap: () => setState(() {
                        if (_allergies.contains(a)) {
                          _allergies.remove(a);
                        } else {
                          _allergies.add(a);
                        }
                      }),
                    ))
                .toList(),
          ),
          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              widget.onUpdate(widget.draft.copyWith(
                dietaryStyle: _diet,
                allergies: _allergies,
              ));
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle() => TextStyle(
        fontSize: 13,
        color: AppColors.textHint,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      );
}

// ============================================================================
// SCREEN 6 — Tone slider + ED safety gate
// ============================================================================
class _Tone extends StatefulWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onUpdate;
  final VoidCallback onNext;

  const _Tone({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<_Tone> createState() => _ToneState();
}

class _ToneState extends State<_Tone> {
  late String _tone = widget.draft.tone;
  late bool _ack = widget.draft.edSafetyAcknowledged;

  static const _tones = ['polite', 'cheeky', 'savage'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Pick your Caliana'),
          const _Subtitle(
              'Same character, three modes. Switch any time in Settings.'),
          const SizedBox(height: 22),
          ..._tones.map((value) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CharacterCard(
                  value: value,
                  selected: _tone == value,
                  onTap: () => setState(() => _tone = value),
                ),
              )),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _ack = !_ack),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _ack
                      ? AppColors.primary
                      : AppColors.surfaceBorder,
                  width: _ack ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _ack
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _ack
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                        width: 1.5,
                      ),
                    ),
                    child: _ack
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Caliana talks back. If you have a history of disordered '
                      'eating, please choose Polite or use a different app. '
                      'Caliana will never shame your body — only the choices.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _PrimaryButton(
            label: 'Continue',
            enabled: _ack,
            onTap: () {
              widget.onUpdate(widget.draft.copyWith(
                tone: _tone,
                edSafetyAcknowledged: true,
              ));
              widget.onNext();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 7 — Notification windows
// ============================================================================
class _Notifications extends StatefulWidget {
  final UserProfile draft;
  final ValueChanged<UserProfile> onUpdate;
  final VoidCallback onNext;

  const _Notifications({
    required this.draft,
    required this.onUpdate,
    required this.onNext,
  });

  @override
  State<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<_Notifications> {
  late final Set<int> _hours = widget.draft.notificationHours.toSet();

  static const _windows = [
    {'hour': 13, 'label': 'Lunch check-in', 'sub': '~1pm'},
    {'hour': 19, 'label': 'Dinner check-in', 'sub': '~7pm'},
    {'hour': 22, 'label': 'Late-night raid', 'sub': '~10pm'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('When can Caliana ping?'),
          const _Subtitle('Max one push a day. She\'s not Duolingo.'),
          const SizedBox(height: 22),
          ..._windows.map((w) {
            final h = w['hour'] as int;
            final selected = _hours.contains(h);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalCard(
                emoji: '🔔',
                title: w['label'] as String,
                sub: w['sub'] as String,
                selected: selected,
                onTap: () => setState(() {
                  if (selected) {
                    _hours.remove(h);
                  } else {
                    _hours.add(h);
                  }
                }),
              ),
            );
          }),
          const Spacer(),
          _PrimaryButton(
            label: 'Continue',
            onTap: () {
              widget.onUpdate(widget.draft.copyWith(
                notificationHours: _hours.toList()..sort(),
              ));
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 8 — Plan reveal (Caliana shows the math)
// ============================================================================
class _PlanReveal extends StatefulWidget {
  final UserProfile draft;
  final VoidCallback onNext;

  const _PlanReveal({required this.draft, required this.onNext});

  @override
  State<_PlanReveal> createState() => _PlanRevealState();
}

class _PlanRevealState extends State<_PlanReveal> {
  int _shownKcal = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 18), (t) {
      final target = widget.draft.dailyCalorieGoal;
      if (_shownKcal >= target) {
        t.cancel();
        return;
      }
      setState(() {
        _shownKcal = (_shownKcal + (target ~/ 60)).clamp(0, target);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.draft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Here\'s your plan'),
          const _Subtitle('Caliana ran the numbers.'),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  '$_shownKcal',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                    letterSpacing: -3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'kcal per day',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textHint,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: GlassDecoration.card(opacity: 0.05),
            child: Column(
              children: [
                _planRow('Protein', '${p.dailyProteinGrams} g',
                    AppColors.macroProtein),
                _planRow('Carbs', '${p.dailyCarbsGrams} g',
                    AppColors.macroCarbs),
                _planRow('Fat', '${p.dailyFatGrams} g', AppColors.macroFat),
              ],
            ),
          ),
          const Spacer(),
          _PrimaryButton(label: 'Looks good', onTap: widget.onNext),
        ],
      ),
    );
  }

  Widget _planRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 9 — Caliana's promise (no fabricated reviews)
// ============================================================================
class _SocialProof extends StatelessWidget {
  final VoidCallback onNext;
  const _SocialProof({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          const _Title('Caliana\'s deal with you'),
          const _Subtitle('Three things she promises.'),
          const SizedBox(height: 24),
          Center(
            child: Image.asset(
              'assets/caliana.png',
              width: 130,
              height: 130,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 18),
          _promise('💯', 'Honest billing',
              'Cancel in two taps. No tricks, no hidden weekly charges.'),
          const SizedBox(height: 10),
          _promise('🤝', 'No body shame',
              'She\'ll roast your choices, never your body. Pick Polite anytime.'),
          const SizedBox(height: 10),
          _promise('🛠️', 'Fix bad days',
              'Blow lunch? She rebuilds the next 1–3 days, not just nags you.'),
          const Spacer(),
          _PrimaryButton(label: 'Show me', onTap: onNext),
        ],
      ),
    );
  }

  Widget _promise(String emoji, String title, String body) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: GlassDecoration.card(opacity: 0.05),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCREEN 10 — Soft paywall (the gift)
// ============================================================================
class _SoftPaywall extends StatefulWidget {
  final VoidCallback onContinueFree;
  final VoidCallback onSubscribe;

  const _SoftPaywall({required this.onContinueFree, required this.onSubscribe});

  @override
  State<_SoftPaywall> createState() => _SoftPaywallState();
}

class _SoftPaywallState extends State<_SoftPaywall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _giftBlue = Color(0xFF2F6BFF);
  static const _giftBlueLight = Color(0xFF5A8AFF);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gift hero — no grey, no emoji.
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_giftBlueLight, _giftBlue],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _giftBlue.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'A gift from Caliana.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '3 days of full access. Properly free —\nno card, no catch, no nonsense.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.45,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 26),
          _animatedRow(0, Icons.camera_alt_rounded,
              'Snap anything', 'She works out the calories.'),
          _animatedRow(1, Icons.graphic_eq_rounded,
              'Hear her voice', 'British, sharp, on demand.'),
          _animatedRow(2, Icons.auto_awesome_rounded,
              'She fixes bad days', 'Tomorrow rebuilds itself.'),
          _animatedRow(3, Icons.restaurant_rounded,
              'Real recipes', 'From the world\'s kitchens, scaled to your day.'),
          const SizedBox(height: 28),
          _PrimaryButton(
            label: 'Claim my 3 days',
            onTap: () async {
              HapticFeedback.mediumImpact();
              // Push the real paywall so live store prices show. The
              // gift trial is already running locally regardless of
              // what they pick — so finishing onboarding either way
              // is fine.
              final purchased = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      const PaywallScreen(triggerText: 'onboarding'),
                ),
              );
              if (purchased == true) {
                await UsageService.instance.setPro(true);
              }
              widget.onSubscribe();
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: widget.onContinueFree,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Text(
                  'Just take me in',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedRow(int i, IconData icon, String title, String sub) {
    final start = (i * 0.12).clamp(0.0, 1.0);
    final end = (start + 0.55).clamp(0.0, 1.0);
    final t = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (_, __) {
        return Opacity(
          opacity: t.value,
          child: Transform.translate(
            offset: Offset(0, (1 - t.value) * 14),
            child: _featureRow(icon, title, sub),
          ),
        );
      },
    );
  }

  Widget _featureRow(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_giftBlueLight, _giftBlue],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _giftBlue.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared widgets used across onboarding screens
// ============================================================================
class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: -1.2,
        height: 1.05,
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final String text;
  const _Subtitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.4,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5A8AFF),
                      Color(0xFF2F6BFF),
                      Color(0xFF1F4FE0),
                    ],
                  )
                : null,
            color: enabled ? null : AppColors.backgroundDeep,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : AppColors.textHint,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: GlassDecoration.card(opacity: 0.04, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
              ),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
