import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
      'firstName': _firstName(profile.name),
      'day': _dayContext(today, profile),
      'recentPattern': _recentPatternContext(profile),
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
        debugPrint('Caliana chat ${res.statusCode}: ${res.body}');
        return _localFallbackReply(userText, profile, today);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final text = (data['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        // Backend OK but model returned empty. Fall back so the bubble
        // never renders silent.
        return _localFallbackReply(userText, profile, today);
      }
      return CalianaReply(
        text: text,
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
    final tone = UserProfileService.instance.profile.tone;
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/caliana-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text.trim(), 'tone': tone}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        final msg =
            res.body.length > 400 ? '${res.body.substring(0, 400)}…' : res.body;
        debugPrint('🔇 Caliana voice ${res.statusCode}: $msg');
        _lastVoiceError = 'Voice ${res.statusCode}: $msg';
        return null;
      }
      if (res.bodyBytes.isEmpty) {
        debugPrint('🔇 Caliana voice: 200 OK but empty body');
        _lastVoiceError = 'Voice route returned empty audio';
        return null;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/caliana_voice_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await file.writeAsBytes(res.bodyBytes, flush: true);
      _lastVoiceError = null;
      return file.path;
    } catch (e) {
      debugPrint('🔇 Caliana voice error: $e');
      _lastVoiceError = 'Voice error: $e';
      return null;
    }
  }

  /// Last error from synthesizeVoice — surfaced in a SnackBar by today_screen
  /// once per session so the user knows when voice is silent.
  String? _lastVoiceError;
  String? get lastVoiceError => _lastVoiceError;
  void clearLastVoiceError() => _lastVoiceError = null;

  /// Hit the backend's /api/diagnose endpoint. Returns the parsed JSON or
  /// throws with a useful message. Used by the Settings "Test voice"
  /// button so the user can see exactly what's broken without hunting in
  /// device logs.
  Future<Map<String, dynamic>> diagnose() async {
    if (_baseUrl.isEmpty) {
      throw Exception('Backend URL not set');
    }
    final res = await http
        .get(Uri.parse('$_baseUrl/api/diagnose'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Diagnose ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// End-to-end voice test: synthesise a short line, return the local
  /// file path so the caller can play it. Throws with a precise reason
  /// if anything is off.
  Future<String> testVoice() async {
    if (_baseUrl.isEmpty) {
      throw Exception('Backend URL not set');
    }
    final path = await synthesizeVoice('Right then. Voice check, all working.');
    if (path == null) {
      throw Exception(_lastVoiceError ?? 'Voice synthesis returned no audio');
    }
    return path;
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
      _lastFoodLogError = 'Backend URL not set — connect to Caliana';
      return null;
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
        _lastFoodLogError =
            'Couldn\'t analyse that. (${res.statusCode})';
        debugPrint('parseFoodFromText ${res.statusCode}: ${res.body}');
        return null;
      }
      _lastFoodLogError = null;
      return _entryFromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        inputMethod: inputMethod,
      );
    } catch (e) {
      debugPrint('parseFoodFromText error: $e');
      _lastFoodLogError = 'Couldn\'t reach Caliana — check connection';
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Food parsing — photo path → FoodEntry
  // ---------------------------------------------------------------------------
  Future<FoodEntry?> parseFoodFromPhoto(String photoPath, {String? hint}) async {
    if (_baseUrl.isEmpty) {
      _lastFoodLogError = 'Backend URL not set — connect to Caliana';
      return null;
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
        _lastFoodLogError =
            'Couldn\'t read the photo. (${res.statusCode})';
        debugPrint('parseFoodFromPhoto ${res.statusCode}: ${res.body}');
        return null;
      }
      _lastFoodLogError = null;
      return _entryFromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
        inputMethod: 'photo',
        photoPath: photoPath,
      );
    } catch (e) {
      debugPrint('parseFoodFromPhoto error: $e');
      _lastFoodLogError = 'Couldn\'t read the photo — check connection';
      return null;
    }
  }

  /// Last food-log failure surfaced via UI snackbar so users never see
  /// a silent fake "Caesar salad" estimate again.
  String? _lastFoodLogError;
  String? get lastFoodLogError => _lastFoodLogError;
  void clearLastFoodLogError() => _lastFoodLogError = null;

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

  /// Just the first word of the user's name (or empty). The agent uses
  /// this for direct address; clinical full names break the vibe.
  String _firstName(String fullName) {
    final t = fullName.trim();
    if (t.isEmpty) return '';
    final parts = t.split(RegExp(r'\s+'));
    return parts.first;
  }

  /// Rolling summary of the last few days so the agent can callback to
  /// patterns ("third coffee day in a row", "fourth time over this week").
  /// Empty string if there's nothing logged yet.
  String _recentPatternContext(UserProfile profile) {
    final svc = DayLogService.instance;
    final goal = profile.dailyCalorieGoal;
    final now = DateTime.now();
    final summaries = <String>[];
    int daysWithLogs = 0;
    int daysOver = 0;
    int totalCalories = 0;
    final foodCounts = <String, int>{};

    // Look back 3 days BEFORE today so the agent can reference yesterday
    // and the day before without double-counting today.
    for (int i = 1; i <= 3; i++) {
      final d = now.subtract(Duration(days: i));
      final log = svc.forDay(d);
      if (log.entries.isEmpty) continue;
      daysWithLogs++;
      final cals = log.totalCalories;
      totalCalories += cals;
      if (goal > 0 && cals > goal) daysOver++;
      summaries.add(
        '${_dayLabel(i)}: $cals kcal, ${log.entries.length} entries',
      );
      for (final e in log.entries) {
        final name = e.name.toLowerCase().trim();
        if (name.isEmpty) continue;
        foodCounts[name] = (foodCounts[name] ?? 0) + 1;
      }
    }

    if (daysWithLogs == 0) return '(no entries in the last 3 days)';

    final repeats = foodCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => '${e.key} ×${e.value}')
        .take(3)
        .toList();

    final avg = (totalCalories / daysWithLogs).round();
    final lines = <String>[
      '${summaries.join('; ')}.',
      'Average: $avg kcal/day across $daysWithLogs day${daysWithLogs == 1 ? '' : 's'}.',
    ];
    if (goal > 0 && daysOver > 0) {
      lines.add('Over goal: $daysOver of $daysWithLogs.');
    }
    if (repeats.isNotEmpty) {
      lines.add('Repeated foods: ${repeats.join(', ')}.');
    }
    return lines.join(' ');
  }

  String _dayLabel(int daysAgo) {
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo == 2) return '2 days ago';
    return '$daysAgo days ago';
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
  // Tone-aware, randomised, viral-by-default so the UI never feels dead even
  // when the network is down.
  // ---------------------------------------------------------------------------
  static final Random _rng = Random();

  String _pick(List<String> options) =>
      options[_rng.nextInt(options.length)];

  CalianaReply _localFallbackReply(
    String userText,
    UserProfile profile,
    DayLog today,
  ) {
    final consumed = today.totalCalories;
    final goal = profile.dailyCalorieGoal;
    final pct = goal == 0 ? 0.0 : consumed * 100.0 / goal;
    final lower = userText.toLowerCase();
    final tone = profile.tone; // 'polite' | 'cheeky' | 'savage'

    // Specific quick-action triggers — short, decisive, tone-aware.
    if (lower.contains('fix my day')) {
      return CalianaReply(
        text: _pick(_fixMyDay[tone] ?? _fixMyDay['cheeky']!),
        actionChips: const ['Suggest dinner'],
      );
    }
    if (lower.contains('high-protein') || lower.contains('high protein')) {
      return CalianaReply(
        text: _pick(_highProtein[tone] ?? _highProtein['cheeky']!),
      );
    }
    if (lower.contains('clean')) {
      return CalianaReply(text: _pick(_clean[tone] ?? _clean['cheeky']!));
    }
    if (lower.contains('junk') || lower.contains('balance')) {
      return CalianaReply(
        text: _pick(_balanceJunk[tone] ?? _balanceJunk['cheeky']!),
      );
    }
    if (lower.contains('quick lunch') || lower.contains('10-minute')) {
      return CalianaReply(
        text: _pick(_quickLunch[tone] ?? _quickLunch['cheeky']!),
      );
    }

    // Calorie-progress reactions — randomised so it never feels canned.
    final List<String> bucket;
    final List<String> chips;
    if (pct < 50) {
      bucket = _under50[tone] ?? _under50['cheeky']!;
      chips = const [];
    } else if (pct < 90) {
      bucket = _half[tone] ?? _half['cheeky']!;
      chips = const [];
    } else if (pct < 110) {
      bucket = _tight[tone] ?? _tight['cheeky']!;
      chips = const ['Suggest dinner'];
    } else {
      bucket = _over[tone] ?? _over['cheeky']!;
      chips = const ['Fix the week'];
    }
    return CalianaReply(text: _pick(bucket), actionChips: chips);
  }

  // Quick-action one-liner pools, keyed by tone.
  static const Map<String, List<String>> _fixMyDay = {
    'polite': [
      "Sorted, love. Dinner adjusted.",
      "Right then — light tea, easy walk.",
      "On it. We tidy this up.",
    ],
    'cheeky': [
      "Sorted. Dinner stays civil.",
      "Right, easy fix. Lighter tea.",
      "Behave. Soup tonight, you menace.",
      "Fair play. We trim 300 off dinner.",
    ],
    'savage': [
      "Damage report received. Salad for tea.",
      "We move. Dinner pays the bill.",
      "Absolute mare. Fixing it now.",
    ],
  };

  static const Map<String, List<String>> _highProtein = {
    'polite': [
      "Lovely. Chicken bowl, eggs on toast.",
      "Try Greek yoghurt and berries. Tidy.",
    ],
    'cheeky': [
      "Chicken bowl. Eggs on toast. Sorted.",
      "Greek yog and berries. Behave.",
      "Tuna wrap. Proper fuel.",
    ],
    'savage': [
      "Chicken. Plain. Like your week deserves.",
      "Eggs on toast. Decisive choice for once.",
    ],
  };

  static const Map<String, List<String>> _clean = {
    'polite': [
      "Salmon and greens. Lovely choice.",
      "Grilled fish, lemon, leaves. Tidy.",
    ],
    'cheeky': [
      "Salmon plus greens. Done.",
      "Grilled fish, big salad. Smashing.",
    ],
    'savage': [
      "Salmon. Greens. Penance for the croissant.",
      "Fish and leaves. Unrecognisable behaviour.",
    ],
  };

  static const Map<String, List<String>> _balanceJunk = {
    'polite': [
      "All good — we balance it tomorrow.",
      "Right then, light dinner sorts it.",
    ],
    'cheeky': [
      "Alright. We balance it. Behave tomorrow.",
      "Sorted. Light tea, no further crimes.",
    ],
    'savage': [
      "Confessed. Penance: dinner of leaves.",
      "Noted, your honour. We rebuild.",
    ],
  };

  static const Map<String, List<String>> _quickLunch = {
    'polite': [
      "Tuna wrap. Five minutes. Lovely.",
      "Eggs on toast. Easy and sound.",
    ],
    'cheeky': [
      "Tuna wrap. Five minutes. Sorted.",
      "Eggs on toast. Behave, that's lunch.",
    ],
    'savage': [
      "Tuna wrap. Five minutes. Try not to ruin it.",
      "Eggs on toast. Even you can manage.",
    ],
  };

  // Calorie-progress pools. Specific, dry, British. No "Reader," / "Behold,".
  static const Map<String, List<String>> _under50 = {
    'polite': [
      "Clean slate, love. Make it count.",
      "Right then — fresh start. Tidy.",
      "Plenty of room. Pick something proper.",
    ],
    'cheeky': [
      "Clean slate. Don't waste it.",
      "Plenty in the tank. Behave.",
      "Loads of room. Don't blow it on crisps.",
      "Right, blank canvas. Make it count.",
    ],
    'savage': [
      "Fresh slate. Try not to wreck it by ten.",
      "Vast reserves. Audacious, given last week.",
      "Empty diary. Don't get clever.",
    ],
  };

  static const Map<String, List<String>> _half = {
    'polite': [
      "Halfway there. Light dinner sorts it.",
      "On track, love. Easy tea tonight.",
    ],
    'cheeky': [
      "Halfway. Dinner stays civil.",
      "On the rails. Behave at tea.",
      "Smashing. Don't get cocky.",
      "Tidy. Light dinner, stay golden.",
    ],
    'savage': [
      "Halfway. Restraint until tea, please.",
      "Mid-day discipline. Unrecognisable.",
      "On pace. Astonishing.",
    ],
  };

  static const Map<String, List<String>> _tight = {
    'polite': [
      "Bit close — light dinner, yeah?",
      "Snug. I'll pick a small tea.",
    ],
    'cheeky': [
      "Tight. I'll line up a small dinner.",
      "Cutting it fine. Soup tonight.",
      "Borderline. Behave at tea.",
    ],
    'savage': [
      "On the wire. Salad pays the toll.",
      "Snug. The audacity to want dinner.",
    ],
  };

  static const Map<String, List<String>> _over = {
    'polite': [
      "Over today — we rebuild tomorrow.",
      "Past it, love. Easy day next.",
    ],
    'cheeky': [
      "Over. We rebuild tomorrow.",
      "Bit much. Sober dinner sorts it.",
      "Crime scene. Fixing the week.",
    ],
    'savage': [
      "Absolute scenes. We rebuild — silently.",
      "Disaster. Tomorrow does the apologising.",
      "Noted, your honour. The week pays.",
    ],
  };

}

class CalianaReply {
  final String text;
  final List<String> actionChips;
  const CalianaReply({required this.text, this.actionChips = const []});
}

