import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether we've already shown the 5-star review prompt and counts
/// "meaningful events" (logged food entries) so the prompt only appears
/// after the user has actually used the app.
class ReviewPromptService extends ChangeNotifier {
  ReviewPromptService._();
  static final ReviewPromptService _instance = ReviewPromptService._();
  static ReviewPromptService get instance => _instance;

  static const _shownKey = 'caliana_review_prompt_shown_v1';
  static const _eventCountKey = 'caliana_review_event_count_v1';

  /// Show the prompt once the user has logged at least this many entries.
  /// Picked low so the prompt fires while the app is still fresh in their
  /// mind, but high enough they've genuinely seen value.
  static const _eventThreshold = 3;

  bool _shown = false;
  int _events = 0;
  bool _loaded = false;

  bool get shown => _shown;
  int get events => _events;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _shown = prefs.getBool(_shownKey) ?? false;
      _events = prefs.getInt(_eventCountKey) ?? 0;
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  /// Call when the user does something that shows engagement (food log,
  /// recipe save, etc.). Returns true if the caller should display the
  /// prompt now.
  Future<bool> recordEventAndShouldPrompt() async {
    if (!_loaded) await load();
    if (_shown) return false;
    _events += 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_eventCountKey, _events);
    } catch (_) {}
    notifyListeners();
    return _events >= _eventThreshold;
  }

  Future<void> markShown() async {
    _shown = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shownKey, true);
    } catch (_) {}
  }
}
