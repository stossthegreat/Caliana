import 'dart:convert';

/// Everything Caliana knows about the user — used to compute goals
/// and shape every interjection.
class UserProfile {
  final String name;
  final String sex; // 'female', 'male', 'other'
  final int ageYears;
  final double heightCm;
  final double weightKg;

  /// 'lose', 'maintain', 'gain'
  final String goalType;

  final double targetWeightKg;

  /// ISO yyyy-mm-dd, optional.
  final String? targetDate;

  /// 'couch', 'light', 'active', 'athlete'
  final String activityLevel;

  /// Manual override of computed daily calorie goal (0 = use computed).
  final int dailyCalorieGoalOverride;

  /// Macro split percentages (must sum to 100). Default balanced 30/40/30.
  final int proteinPercent;
  final int carbsPercent;
  final int fatPercent;

  /// 'none', 'vegetarian', 'vegan', 'pescatarian', 'keto', 'paleo', 'gluten-free', 'halal'
  final String dietaryStyle;

  final List<String> allergies;

  /// Caliana's tone: 'polite', 'cheeky', 'savage'
  final String tone;

  /// Hours of day Caliana is allowed to ping (24-hour, in user's local time).
  /// Defaults to lunch + dinner + late-night windows.
  final List<int> notificationHours;

  /// User has acknowledged the ED safety gate.
  final bool edSafetyAcknowledged;

  /// User completed full onboarding (all 10 screens, including data + goals).
  final bool onboardingComplete;

  const UserProfile({
    this.name = '',
    this.sex = 'other',
    this.ageYears = 30,
    this.heightCm = 170,
    this.weightKg = 70,
    this.goalType = 'maintain',
    this.targetWeightKg = 70,
    this.targetDate,
    this.activityLevel = 'light',
    this.dailyCalorieGoalOverride = 0,
    this.proteinPercent = 30,
    this.carbsPercent = 40,
    this.fatPercent = 30,
    this.dietaryStyle = 'none',
    this.allergies = const [],
    this.tone = 'cheeky',
    this.notificationHours = const [13, 19, 22],
    this.edSafetyAcknowledged = false,
    this.onboardingComplete = false,
  });

  // ---------------------------------------------------------------------------
  // Computed nutrition targets
  // ---------------------------------------------------------------------------

  /// Mifflin-St Jeor BMR (kcal/day at rest).
  double get bmr {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
    if (sex == 'male') return base + 5;
    if (sex == 'female') return base - 161;
    return base - 78; // 'other' → midpoint
  }

  /// Total Daily Energy Expenditure — BMR × activity multiplier.
  double get tdee {
    const multipliers = {
      'couch': 1.2,
      'light': 1.375,
      'active': 1.55,
      'athlete': 1.725,
    };
    return bmr * (multipliers[activityLevel] ?? 1.375);
  }

  /// Daily calorie target. Lose = -500/day (1 lb/wk). Gain = +400/day.
  int get dailyCalorieGoal {
    if (dailyCalorieGoalOverride > 0) return dailyCalorieGoalOverride;
    final base = tdee;
    final adjusted = switch (goalType) {
      'lose' => base - 500,
      'gain' => base + 400,
      _ => base,
    };
    return adjusted.round();
  }

  /// Weekly calorie budget — what the rolling-7 ring uses.
  int get weeklyCalorieGoal => dailyCalorieGoal * 7;

  /// Daily protein target in grams (rounded). Caps at 2g/kg for sanity.
  int get dailyProteinGrams {
    final fromPercent = (dailyCalorieGoal * proteinPercent / 100) / 4;
    final fromBodyweight = weightKg * 1.6;
    return fromPercent.clamp(fromBodyweight * 0.7, weightKg * 2.2).round();
  }

  int get dailyCarbsGrams =>
      ((dailyCalorieGoal * carbsPercent / 100) / 4).round();

  int get dailyFatGrams =>
      ((dailyCalorieGoal * fatPercent / 100) / 9).round();

  /// Has the user given us enough to coach them properly?
  bool get isConfigured =>
      onboardingComplete && weightKg > 0 && heightCm > 0 && ageYears > 0;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  UserProfile copyWith({
    String? name,
    String? sex,
    int? ageYears,
    double? heightCm,
    double? weightKg,
    String? goalType,
    double? targetWeightKg,
    String? targetDate,
    String? activityLevel,
    int? dailyCalorieGoalOverride,
    int? proteinPercent,
    int? carbsPercent,
    int? fatPercent,
    String? dietaryStyle,
    List<String>? allergies,
    String? tone,
    List<int>? notificationHours,
    bool? edSafetyAcknowledged,
    bool? onboardingComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      sex: sex ?? this.sex,
      ageYears: ageYears ?? this.ageYears,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalType: goalType ?? this.goalType,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetDate: targetDate ?? this.targetDate,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyCalorieGoalOverride:
          dailyCalorieGoalOverride ?? this.dailyCalorieGoalOverride,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      carbsPercent: carbsPercent ?? this.carbsPercent,
      fatPercent: fatPercent ?? this.fatPercent,
      dietaryStyle: dietaryStyle ?? this.dietaryStyle,
      allergies: allergies ?? this.allergies,
      tone: tone ?? this.tone,
      notificationHours: notificationHours ?? this.notificationHours,
      edSafetyAcknowledged: edSafetyAcknowledged ?? this.edSafetyAcknowledged,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex,
        'ageYears': ageYears,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goalType': goalType,
        'targetWeightKg': targetWeightKg,
        'targetDate': targetDate,
        'activityLevel': activityLevel,
        'dailyCalorieGoalOverride': dailyCalorieGoalOverride,
        'proteinPercent': proteinPercent,
        'carbsPercent': carbsPercent,
        'fatPercent': fatPercent,
        'dietaryStyle': dietaryStyle,
        'allergies': allergies,
        'tone': tone,
        'notificationHours': notificationHours,
        'edSafetyAcknowledged': edSafetyAcknowledged,
        'onboardingComplete': onboardingComplete,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        sex: json['sex'] ?? 'other',
        ageYears: json['ageYears'] ?? 30,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
        goalType: json['goalType'] ?? 'maintain',
        targetWeightKg:
            (json['targetWeightKg'] as num?)?.toDouble() ?? 70,
        targetDate: json['targetDate'] as String?,
        activityLevel: json['activityLevel'] ?? 'light',
        dailyCalorieGoalOverride: json['dailyCalorieGoalOverride'] ?? 0,
        proteinPercent: json['proteinPercent'] ?? 30,
        carbsPercent: json['carbsPercent'] ?? 40,
        fatPercent: json['fatPercent'] ?? 30,
        dietaryStyle: json['dietaryStyle'] ?? 'none',
        allergies: List<String>.from(json['allergies'] ?? const []),
        tone: json['tone'] ?? 'cheeky',
        notificationHours:
            List<int>.from(json['notificationHours'] ?? const [13, 19, 22]),
        edSafetyAcknowledged: json['edSafetyAcknowledged'] ?? false,
        onboardingComplete: json['onboardingComplete'] ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String s) =>
      UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);

  /// Compact context string sent to Caliana on every message so she
  /// "remembers" who the user is.
  String toAgentContext() {
    final parts = <String>[
      'Name: ${name.isEmpty ? 'unknown' : name}',
      'Sex: $sex, age $ageYears',
      'Height ${heightCm.round()}cm, current weight ${weightKg.toStringAsFixed(1)}kg',
      'Goal: $goalType (target ${targetWeightKg.toStringAsFixed(1)}kg${targetDate != null ? ' by $targetDate' : ''})',
      'Activity: $activityLevel',
      'Daily target: $dailyCalorieGoal kcal '
          '($dailyProteinGrams P / $dailyCarbsGrams C / $dailyFatGrams F)',
      'Tone preference: $tone',
    ];
    if (dietaryStyle != 'none') parts.add('Diet: $dietaryStyle');
    if (allergies.isNotEmpty) parts.add('MUST AVOID: ${allergies.join(', ')}');
    return parts.join('\n');
  }
}
