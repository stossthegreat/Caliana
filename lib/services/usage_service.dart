import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Free-tier gating for Caliana.
///
/// Caliana ships a 3-day "gift trial" — every new user gets full
/// unlimited access for 72 hours from first launch. After that the
/// paywall opens on any premium action (snap, voice, multi-day plan,
/// recap export). Pro subscribers (RevenueCat `pro` entitlement) skip
/// the gate entirely.
///
/// Per-day free-tier photo cap kept as a safety belt for users who
/// dismiss the paywall and stay on the trial-expired free tier — they
/// still get 1 photo a day so the app isn't a black hole.
class UsageService extends ChangeNotifier {
  UsageService._();
  static final UsageService _instance = UsageService._();
  static UsageService get instance => _instance;

  static const _photoCountKey = 'caliana_photo_count_v1';
  static const _photoCountDateKey = 'caliana_photo_count_date_v1';
  static const _isProKey = 'caliana_is_pro';
  static const _hasRatedKey = 'caliana_has_rated';
  static const _totalPhotosKey = 'caliana_total_photos';
  static const _firstLaunchKey = 'caliana_first_launch_iso_v1';

  /// Free users get 1 photo analysis per calendar day after the trial.
  static const int dailyFreePhotos = 1;

  /// Every user gets this many days of full unlimited access from
  /// first app launch — Caliana's "gift trial".
  static const int giftTrialDays = 3;

  int _photosToday = 0;
  String _photosTodayDate = '';
  bool _isPro = false;
  bool _hasRated = false;
  int _totalPhotos = 0;
  DateTime? _firstLaunch;

  bool _loaded = false;
  bool get loaded => _loaded;

  // ---- public getters ----

  bool get isPro => _isPro;

  /// True for the first [giftTrialDays] after first app launch.
  /// Treats the user as if they have Pro for unlimited access.
  bool get isInGiftTrial {
    if (_firstLaunch == null) return true; // brand-new user, treat as in trial
    final cutoff =
        _firstLaunch!.add(const Duration(days: giftTrialDays));
    return DateTime.now().isBefore(cutoff);
  }

  /// 0 when the trial has ended, otherwise the rounded-up days left
  /// so the UI can say "1 day left".
  int get giftTrialDaysLeft {
    if (_firstLaunch == null) return giftTrialDays;
    final cutoff =
        _firstLaunch!.add(const Duration(days: giftTrialDays));
    final now = DateTime.now();
    if (!now.isBefore(cutoff)) return 0;
    final hoursLeft = cutoff.difference(now).inHours;
    return (hoursLeft / 24).ceil().clamp(0, giftTrialDays);
  }

  /// True when the user has full premium-feature access — either via
  /// Pro subscription OR the gift trial window.
  bool get hasPremiumAccess => isPro || isInGiftTrial;

  int get photosUsedToday {
    _rolloverIfNeeded();
    return _photosToday;
  }

  int get photosRemainingToday {
    if (hasPremiumAccess) return 999;
    _rolloverIfNeeded();
    return (dailyFreePhotos - _photosToday).clamp(0, dailyFreePhotos);
  }

  bool get canSnapPhoto =>
      hasPremiumAccess || photosRemainingToday > 0;

  bool get canVoiceReply => hasPremiumAccess;
  bool get canShareRecap => hasPremiumAccess;
  bool get canMultiDayPlan => hasPremiumAccess;

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
      // Stamp the first-launch timestamp so the 2-day gift trial
      // clock starts ticking from the user's actual first run.
      final stored = prefs.getString(_firstLaunchKey);
      if (stored == null || stored.isEmpty) {
        _firstLaunch = DateTime.now();
        await prefs.setString(
          _firstLaunchKey,
          _firstLaunch!.toIso8601String(),
        );
      } else {
        _firstLaunch = DateTime.tryParse(stored);
      }
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
    // Don't reset _firstLaunch — that would let any user retrigger
    // the gift trial by clearing the app data. The trial is one-shot.
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
