import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Free-tier gating for Caliana.
///
/// Free tier:
///   - 1 PHOTO analysis per day (the wow moment)
///   - Unlimited text/voice/barcode logging
///   - Unlimited chat with Caliana
///
/// Pro tier:
///   - Unlimited photos
///   - Voice replies (ElevenLabs)
///   - Sunday recap share-card export
///   - Multi-day rebuild plans
class UsageService extends ChangeNotifier {
  UsageService._();
  static final UsageService _instance = UsageService._();
  static UsageService get instance => _instance;

  static const _photoCountKey = 'caliana_photo_count_v1';
  static const _photoCountDateKey = 'caliana_photo_count_date_v1';
  static const _isProKey = 'caliana_is_pro';
  static const _hasRatedKey = 'caliana_has_rated';
  static const _totalPhotosKey = 'caliana_total_photos';

  /// Free users get 1 photo analysis per calendar day.
  static const int dailyFreePhotos = 1;

  int _photosToday = 0;
  String _photosTodayDate = '';
  bool _isPro = false;
  bool _hasRated = false;
  int _totalPhotos = 0;

  bool _loaded = false;
  bool get loaded => _loaded;

  // ---- public getters ----

  bool get isPro => _isPro;
  int get photosUsedToday {
    _rolloverIfNeeded();
    return _photosToday;
  }

  int get photosRemainingToday {
    if (isPro) return 999;
    _rolloverIfNeeded();
    return (dailyFreePhotos - _photosToday).clamp(0, dailyFreePhotos);
  }

  bool get canSnapPhoto =>
      isPro || photosRemainingToday > 0;

  bool get canVoiceReply => isPro;
  bool get canShareRecap => isPro;
  bool get canMultiDayPlan => isPro;

  int get totalPhotos => _totalPhotos;
  bool get hasRated => _hasRated;

  /// Show in-app rating prompt after 3 successful photo logs.
  bool get shouldShowRating => _totalPhotos >= 3 && !_hasRated;

  // ---- lifecycle ----

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _photosToday = prefs.getInt(_photoCountKey) ?? 0;
      _photosTodayDate = prefs.getString(_photoCountDateKey) ?? '';
      _isPro = prefs.getBool(_isProKey) ?? false;
      _hasRated = prefs.getBool(_hasRatedKey) ?? false;
      _totalPhotos = prefs.getInt(_totalPhotosKey) ?? 0;
      _rolloverIfNeeded();
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Reset the daily counter when the calendar day flips.
  void _rolloverIfNeeded() {
    final today = _todayKey();
    if (_photosTodayDate != today) {
      _photosToday = 0;
      _photosTodayDate = today;
      // fire-and-forget — UI doesn't wait
      _saveDaily();
    }
  }

  // ---- record usage ----

  Future<void> recordPhoto() async {
    _rolloverIfNeeded();
    _photosToday++;
    _totalPhotos++;
    notifyListeners();
    await _saveAll();
  }

  Future<void> markRated() async {
    _hasRated = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  // ---- pro upgrade (placeholder until RevenueCat) ----

  Future<void> setPro(bool value) async {
    _isPro = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProKey, value);
  }

  Future<void> reset() async {
    _photosToday = 0;
    _totalPhotos = 0;
    _isPro = false;
    _hasRated = false;
    _photosTodayDate = _todayKey();
    notifyListeners();
    await _saveAll();
  }

  Future<void> _saveDaily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_photoCountKey, _photosToday);
      await prefs.setString(_photoCountDateKey, _photosTodayDate);
    } catch (_) {}
  }

  Future<void> _saveAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_photoCountKey, _photosToday);
      await prefs.setString(_photoCountDateKey, _photosTodayDate);
      await prefs.setInt(_totalPhotosKey, _totalPhotos);
    } catch (_) {}
  }
}
