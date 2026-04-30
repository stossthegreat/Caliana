import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/app_settings_service.dart';
import '../services/usage_service.dart';
import '../services/day_log_service.dart';
import '../services/saved_meals_service.dart';
import '../services/consent_service.dart';
import '../screens/onboarding_screen.dart';
import '../screens/consent_screen.dart';
import '../widgets/aurora_background.dart';

/// Caliana's settings — slim, single-page, navy/coral. Tone slider lives here.
/// All goal data is editable; updating instantly recomputes daily/weekly targets.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserProfile _draft;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _draft = UserProfileService.instance.profile;
    _nameController = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    await UserProfileService.instance.update(
      _draft.copyWith(name: _nameController.text.trim()),
    );
    if (!mounted) return;
    Navigator.pop(context);
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _proCard(),
                      const SizedBox(height: 16),
                      _section(
                        'Caliana\'s tone',
                        Icons.theater_comedy_rounded,
                        _toneRow(),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Your basics',
                        Icons.person_rounded,
                        _basicsBlock(),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Goal',
                        Icons.flag_rounded,
                        _goalBlock(),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Diet & allergies',
                        Icons.no_food_rounded,
                        _dietBlock(),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        'Daily target',
                        Icons.local_fire_department_rounded,
                        _targetBlock(),
                      ),
                      const SizedBox(height: 22),
                      _sectionLabel('Privacy & data'),
                      const SizedBox(height: 8),
                      _consentRow(),
                      _linkRow(
                        Icons.policy_rounded,
                        'Terms of Service',
                        AppColors.textSecondary,
                        () => _openLegalUrl('https://caliana.app/terms'),
                      ),
                      _linkRow(
                        Icons.privacy_tip_rounded,
                        'Privacy Policy',
                        AppColors.textSecondary,
                        () => _openLegalUrl('https://caliana.app/privacy'),
                      ),
                      _linkRow(
                        Icons.info_outline_rounded,
                        'About Caliana',
                        AppColors.textSecondary,
                        () => _showAbout(),
                        trailing: 'v0.1.0',
                      ),
                      const SizedBox(height: 22),
                      _sectionLabel('Danger zone'),
                      const SizedBox(height: 8),
                      _linkRow(
                        Icons.person_off_rounded,
                        'Delete account',
                        AppColors.error,
                        _confirmDeleteAccount,
                        sub: 'Removes profile, logs, recipes, chat history',
                      ),
                    ],
                  ),
                ),
              ),
              _buildSaveBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _proCard() {
    final isPro = UsageService.instance.isPro;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GlassDecoration.coralCard(opacity: 0.07),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: GlassDecoration.coralFab(),
            child: const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro ? 'Caliana Pro — active' : 'Free tier',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPro
                      ? 'Unlimited photos, voice, recap'
                      : '${UsageService.instance.photosRemainingToday}/1 photo left today',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: GlassDecoration.card(opacity: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _toneRow() {
    return Row(
      children: [
        Expanded(child: _toneBtn('polite', 'Polite', '🤝')),
        const SizedBox(width: 8),
        Expanded(child: _toneBtn('cheeky', 'Cheeky', '😏')),
        const SizedBox(width: 8),
        Expanded(child: _toneBtn('savage', 'Savage', '🔥')),
      ],
    );
  }

  Widget _toneBtn(String value, String label, String emoji) {
    final selected = _draft.tone == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _draft = _draft.copyWith(tone: value));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _basicsBlock() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _segPill('Female', 'female', 'sex')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Male', 'male', 'sex')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Other', 'other', 'sex')),
          ],
        ),
        const SizedBox(height: 12),
        _slider(
          'Age',
          _draft.ageYears.toDouble(),
          14,
          90,
          76,
          '${_draft.ageYears} yrs',
          (v) => setState(
              () => _draft = _draft.copyWith(ageYears: v.round())),
        ),
        _slider(
          'Height',
          _draft.heightCm,
          130,
          220,
          90,
          '${_draft.heightCm.round()} cm',
          (v) => setState(() => _draft = _draft.copyWith(heightCm: v)),
        ),
        _slider(
          'Weight',
          _draft.weightKg,
          35,
          200,
          165,
          '${_draft.weightKg.toStringAsFixed(1)} kg',
          (v) => setState(() => _draft = _draft.copyWith(weightKg: v)),
        ),
      ],
    );
  }

  Widget _goalBlock() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _segPill('Lose', 'lose', 'goal')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Maintain', 'maintain', 'goal')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Gain', 'gain', 'goal')),
          ],
        ),
        if (_draft.goalType != 'maintain')
          _slider(
            'Target weight',
            _draft.targetWeightKg,
            35,
            200,
            165,
            '${_draft.targetWeightKg.toStringAsFixed(1)} kg',
            (v) =>
                setState(() => _draft = _draft.copyWith(targetWeightKg: v)),
          ),
        Row(
          children: [
            Expanded(child: _segPill('Couch', 'couch', 'activity')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Light', 'light', 'activity')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Active', 'active', 'activity')),
            const SizedBox(width: 6),
            Expanded(child: _segPill('Athlete', 'athlete', 'activity')),
          ],
        ),
      ],
    );
  }

  Widget _dietBlock() {
    const diets = [
      'none', 'vegetarian', 'vegan', 'pescatarian', 'keto',
      'paleo', 'gluten-free', 'halal'
    ];
    const allergens = [
      'Gluten', 'Dairy', 'Nuts', 'Peanuts', 'Shellfish', 'Eggs', 'Soy', 'Fish'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: diets.map((d) {
            final selected = _draft.dietaryStyle == d;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _draft = _draft.copyWith(dietaryStyle: d));
              },
              child: _chip(d == 'none' ? 'No restriction' : d, selected),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text('Allergies',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            )),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: allergens.map((a) {
            final selected = _draft.allergies.contains(a);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  final list = List<String>.from(_draft.allergies);
                  if (list.contains(a)) {
                    list.remove(a);
                  } else {
                    list.add(a);
                  }
                  _draft = _draft.copyWith(allergies: list);
                });
              },
              child: _chip(a, selected),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _targetBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            '${_draft.dailyCalorieGoal}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: -1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'kcal/day target',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _miniMacro('P', _draft.dailyProteinGrams, AppColors.macroProtein),
              _miniMacro('C', _draft.dailyCarbsGrams, AppColors.macroCarbs),
              _miniMacro('F', _draft.dailyFatGrams, AppColors.macroFat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMacro(String l, int g, Color c) {
    return Column(
      children: [
        Text(
          '${g}g',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textHint,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _segPill(String label, String value, String field) {
    final selected = switch (field) {
      'sex' => _draft.sex == value,
      'goal' => _draft.goalType == value,
      'activity' => _draft.activityLevel == value,
      _ => false,
    };
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (field == 'sex') _draft = _draft.copyWith(sex: value);
          if (field == 'goal') _draft = _draft.copyWith(goalType: value);
          if (field == 'activity') {
            _draft = _draft.copyWith(activityLevel: value);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    String display,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.12),
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textHint,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _linkRow(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    String? sub,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (sub != null)
                        Text(
                          sub,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      trailing,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: GestureDetector(
              onTap: _save,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF7A6B),
                      Color(0xFFFF5E5B),
                      Color(0xFFE94A6F),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Apple 5.1.1(v): account deletion must complete in-app, in one flow,
  /// with no email or external website. Wipes every piece of user data,
  /// resets the onboarding flag, and pops to a fresh OnboardingScreen.
  void _confirmDeleteAccount() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete account?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          "This wipes your profile, food logs, saved recipes, chat "
          "history, and AI consent on this device. You'll start fresh "
          "from onboarding. Cannot be undone.",
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await DayLogService.instance.wipeAll();
              await UserProfileService.instance.reset();
              await UsageService.instance.reset();
              await AppSettingsService.instance.resetToDefault();
              await SavedMealsService.instance.wipe();
              await ConsentService.instance.revoke();
              await OnboardingScreen.markUnseen();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              // Replace the entire stack so the user lands back on
              // onboarding — no settings, no home behind them.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                    onComplete: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => ConsentScreen(
                            onAccepted: () {
                              Navigator.of(context).pop();
                            },
                            onDeclined: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        (_) => false,
                      );
                    },
                  ),
                ),
                (_) => false,
              );
            },
            child: const Text(
              'Delete account',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Settings → Privacy & data: lets users revoke or re-grant the
  /// AI-data-sharing consent without deleting their account.
  Widget _consentRow() {
    return ListenableBuilder(
      listenable: ConsentService.instance,
      builder: (_, __) {
        final granted = ConsentService.instance.granted;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI data sharing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      granted
                          ? 'Sending text, photos & audio to OpenAI / ElevenLabs.'
                          : 'Off — Caliana works locally only.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: granted,
                activeColor: AppColors.primary,
                onChanged: (v) async {
                  HapticFeedback.lightImpact();
                  if (v) {
                    await ConsentService.instance.grant();
                  } else {
                    await ConsentService.instance.revoke();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLegalUrl(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't open $url"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Caliana',
      applicationVersion: 'v0.1.0',
      applicationLegalese: 'Your sassy British AI nutritionist.',
      children: [
        const SizedBox(height: 12),
        const Text(
          'Caliana uses OpenAI for chat, vision and transcription, and '
          'ElevenLabs for voice synthesis. You control whether your data '
          'is shared with these services from the AI data sharing toggle '
          'above.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}
