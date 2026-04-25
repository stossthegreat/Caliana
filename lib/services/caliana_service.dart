import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/day_log.dart';
import '../models/meal_idea.dart';
export '../models/meal_idea.dart';
import 'app_settings_service.dart';
import 'user_profile_service.dart';
import 'day_log_service.dart';

/// Caliana's brain. Talks to the backend agent endpoints.
///
/// Surfaces:
///   - [chat] : one-shot chat reply (text in, text + optional action chips out)
///   - [parseFoodFromText] : turn freeform text or transcript into a FoodEntry
///   - [parseFoodFromPhoto] : turn an image path into a FoodEntry (Pro-gated)
///   - [synthesizeVoice] : ElevenLabs TTS — saves audio file, returns local path
///   - [suggestMeals] : ask the agent for 2-3 meal ideas (calls /api/meal-suggest)
///
/// All routes have a graceful local fallback so the UI never breaks if the
/// backend is offline.
class CalianaService {
  CalianaService._();
  static final CalianaService instance = CalianaService._();

  String get _baseUrl => AppSettingsService.instance.backendUrl;

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------
  Future<CalianaReply> chat(String userText, {String trigger = 'user'}) async {
    final profile = UserProfileService.instance.profile;
    final today = DayLogService.instance.today;

    if (_baseUrl.isEmpty) {
      return _localFallbackReply(userText, profile, today);
    }

    final body = jsonEncode({
      'message': userText,
      'tone': profile.tone,
      'user': profile.toAgentContext(),
      'day': _dayContext(today, profile),
      'trigger': trigger,
    });

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/caliana-chat'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        return _localFallbackReply(userText, profile, today);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return CalianaReply(
        text: (data['text'] as String?)?.trim() ?? '',
        actionChips: List<String>.from(data['actionChips'] ?? const []),
      );
    } catch (e) {
      debugPrint('Caliana chat error: $e');
      return _localFallbackReply(userText, profile, today);
    }
  }

  // ---------------------------------------------------------------------------
  // Voice — ElevenLabs TTS. Returns local mp3 path, or null on failure.
  // ---------------------------------------------------------------------------
  Future<String?> synthesizeVoice(String text) async {
    if (_baseUrl.isEmpty || text.trim().isEmpty) return null;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/caliana-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text.trim()}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/caliana_voice_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Caliana voice error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Meal suggestions — calls /api/meal-suggest, returns 0..3 ideas with
  // optional recipe links from Serper.
  // ---------------------------------------------------------------------------
  Future<List<MealIdea>> suggestMeals(String ask) async {
    final profile = UserProfileService.instance.profile;
    final today = DayLogService.instance.today;
    final remaining =
        (profile.dailyCalorieGoal - today.totalCalories).clamp(0, 6000);

    if (_baseUrl.isEmpty) return const [];
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/meal-suggest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ask': ask,
              'remainingKcal': remaining,
              'userContext': profile.toAgentContext(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['ideas'] as List? ?? const []);
      return list
          .map((e) => MealIdea.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Caliana suggest error: $e');
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Fridge-aware meal suggestions — calls /api/fridge-suggest with a photo.
  // Vision identifies ingredients, then proposes 2-3 meals that use them
  // and fit the remaining calorie budget.
  // ---------------------------------------------------------------------------
  Future<List<MealIdea>> fridgeSuggest(String photoPath) async {
    final profile = UserProfileService.instance.profile;
    final today = DayLogService.instance.today;
    final remaining =
        (profile.dailyCalorieGoal - today.totalCalories).clamp(0, 6000);

    if (_baseUrl.isEmpty) return const [];
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/fridge-suggest'),
      );
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      req.fields['remainingKcal'] = remaining.toString();
      req.fields['userContext'] = profile.toAgentContext();

      final streamed = await req.send().timeout(const Duration(seconds: 35));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['ideas'] as List? ?? const []);
      return list
          .map((e) => MealIdea.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Caliana fridge error: $e');
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Food parsing — text / voice transcript → FoodEntry
  // ---------------------------------------------------------------------------
  Future<FoodEntry?> parseFoodFromText(String text, {required String inputMethod}) async {
    if (text.trim().isEmpty) return null;

    if (_baseUrl.isEmpty) {
      return _localFallbackEntry(text, inputMethod: inputMethod);
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/log-text'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return _localFallbackEntry(text, inputMethod: inputMethod);
      }
      return _entryFromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        inputMethod: inputMethod,
      );
    } catch (e) {
      debugPrint('parseFoodFromText error: $e');
      return _localFallbackEntry(text, inputMethod: inputMethod);
    }
  }

  // ---------------------------------------------------------------------------
  // Food parsing — photo path → FoodEntry
  // ---------------------------------------------------------------------------
  Future<FoodEntry?> parseFoodFromPhoto(String photoPath, {String? hint}) async {
    if (_baseUrl.isEmpty) {
      return _localFallbackEntry(
        hint ?? 'Photographed meal',
        inputMethod: 'photo',
        photoPath: photoPath,
      );
    }

    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/log-photo'),
      );
      req.files.add(await http.MultipartFile.fromPath('photo', photoPath));
      if (hint != null && hint.isNotEmpty) req.fields['hint'] = hint;

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        return _localFallbackEntry(
          hint ?? 'Photographed meal',
          inputMethod: 'photo',
          photoPath: photoPath,
        );
      }
      return _entryFromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        inputMethod: 'photo',
        photoPath: photoPath,
      );
    } catch (e) {
      debugPrint('parseFoodFromPhoto error: $e');
      return _localFallbackEntry(
        hint ?? 'Photographed meal',
        inputMethod: 'photo',
        photoPath: photoPath,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _dayContext(DayLog today, UserProfile profile) {
    final consumed = today.totalCalories;
    final goal = profile.dailyCalorieGoal;
    final left = goal - consumed;
    final pct = goal == 0 ? 0 : (consumed * 100 / goal).round();
    return '''
Today so far: $consumed kcal logged of $goal target ($pct%) — $left remaining.
Macros today: ${today.totalProtein}g P / ${today.totalCarbs}g C / ${today.totalFat}g F.
Entries today: ${today.entries.length}.
''';
  }

  FoodEntry _entryFromJson(
    Map<String, dynamic> json, {
    required String inputMethod,
    String? photoPath,
  }) {
    return FoodEntry(
      id: 'fe_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      name: (json['name'] as String?)?.trim() ?? 'Logged food',
      calories: (json['calories'] as num?)?.round() ?? 0,
      proteinGrams: (json['protein'] as num?)?.round() ?? 0,
      carbsGrams: (json['carbs'] as num?)?.round() ?? 0,
      fatGrams: (json['fat'] as num?)?.round() ?? 0,
      inputMethod: inputMethod,
      photoPath: photoPath,
      confidence: (json['confidence'] as String?) ?? 'medium',
      notes: (json['notes'] as String?) ?? '',
    );
  }

  // ---------------------------------------------------------------------------
  // Local fallbacks — used until backend routes ship, and as graceful failure.
  // Deterministic so the UI is never empty and demos always work.
  // ---------------------------------------------------------------------------
  CalianaReply _localFallbackReply(
    String userText,
    UserProfile profile,
    DayLog today,
  ) {
    final consumed = today.totalCalories;
    final goal = profile.dailyCalorieGoal;
    final pct = goal == 0 ? 0 : consumed * 100 / goal;
    final lower = userText.toLowerCase();

    // Specific quick-action triggers — keep replies tight.
    if (lower.contains('fix my day')) {
      return const CalianaReply(text: "Sorted. Dinner adjusted.");
    }
    if (lower.contains('high-protein') || lower.contains('high protein')) {
      return const CalianaReply(
        text: "Try chicken bowl or eggs on toast.",
      );
    }
    if (lower.contains('clean')) {
      return const CalianaReply(text: "Salmon + greens. Done.");
    }
    if (lower.contains('junk') || lower.contains('balance')) {
      return const CalianaReply(text: "Alright. I'll balance it.");
    }
    if (lower.contains('quick lunch') || lower.contains('10-minute')) {
      return const CalianaReply(text: "Tuna wrap. Five minutes.");
    }

    if (pct < 50) {
      return const CalianaReply(text: "Clean slate. Don't waste it.");
    }
    if (pct < 90) {
      return CalianaReply(
        text: "Halfway. Dinner stays light.",
      );
    }
    if (pct < 110) {
      return const CalianaReply(
        text: "Tight. I'll suggest dinner.",
        actionChips: ['Suggest dinner'],
      );
    }
    return const CalianaReply(
      text: "Over. We rebuild tomorrow.",
      actionChips: ['Fix the week'],
    );
  }

  FoodEntry _localFallbackEntry(
    String text, {
    required String inputMethod,
    String? photoPath,
  }) {
    final base = text.toLowerCase();
    int kcal = 350;
    int p = 18, c = 35, f = 14;
    if (base.contains('salad')) { kcal = 220; p = 10; c = 18; f = 12; }
    if (base.contains('pizza')) { kcal = 720; p = 28; c = 75; f = 30; }
    if (base.contains('burger')) { kcal = 650; p = 30; c = 40; f = 36; }
    if (base.contains('chicken')) { kcal = 420; p = 38; c = 22; f = 16; }
    if (base.contains('rice')) { kcal = 360; p = 8; c = 65; f = 4; }
    if (base.contains('pasta')) { kcal = 540; p = 18; c = 70; f = 18; }
    if (base.contains('coffee')) { kcal = 80; p = 4; c = 6; f = 4; }
    if (base.contains('apple')) { kcal = 95; p = 0; c = 25; f = 0; }
    if (base.contains('banana')) { kcal = 105; p = 1; c = 27; f = 0; }
    return FoodEntry(
      id: 'fe_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      name: _titleCase(text),
      calories: kcal,
      proteinGrams: p,
      carbsGrams: c,
      fatGrams: f,
      inputMethod: inputMethod,
      photoPath: photoPath,
      confidence: 'low',
      notes: 'Estimated locally — backend offline.',
    );
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class CalianaReply {
  final String text;
  final List<String> actionChips;
  const CalianaReply({required this.text, this.actionChips = const []});
}

