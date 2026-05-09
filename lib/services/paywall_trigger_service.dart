import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usage_service.dart';

/// Decides when to surface the paywall opportunistically. Pro users
/// never see it; everyone else sees it at calibrated "moments of value"
/// during the 3-day trial AND on every premium-action attempt after the
/// trial ends.
///
/// Strategy (modelled on the high-converting Calm/Headspace/Cal AI
/// pattern, adapted to a 3-day trial rather than 7):
///
///   IN-TRIAL (free user, trial active)
///     • Day 1 → fire after 2nd photo logged (first taste of value).
///     • Day 2 → fire on first action of the day (mid-trial reminder).
///     • Day 3 → fire on first action of the day (urgency).
///     • After Caliana sends a recipe pull (perceived value moment).
///     • Hard cooldown: 6 hours between auto-shows so we don't spam.
///
///   POST-TRIAL (free user, trial ended)
///     • Premium-action gates already open the paywall — that path is
///       owned by UsageService.canSnapPhoto / canVoiceReply / etc.
///     • In addition, this service shows the paywall on first action
///       of each calendar day to keep conversion top-of-mind.
///
///   PRO USER
///     • Never. shouldShowOpportunistic() always returns false.
///
/// Counters and timestamps are persisted via SharedPreferences so the
/// strategy survives app restarts.
class PaywallTriggerService extends ChangeNotifier {
  PaywallTriggerService._();
  static final PaywallTriggerService _instance = PaywallTriggerService._();
  static PaywallTriggerService get instance => _instance;

  static const _lastShownIsoKey = 'caliana_paywall_last_shown_iso_v1';
  static const _shownTodayDateKey = 'caliana_paywall_shown_today_date_v1';
  static const _photoCountTriggeredKey = 'caliana_paywall_after_photos_v1';

  /// Min hours between any two opportunistic paywall shows. Hard floor
  /// so the user never sees the paywall twice in a single sitting.
  static const _cooldownHours = 6;

  /// During trial, fire after this many cumulative photos logged.
  /// First fire = 2 (after the user has felt the photo flow work).
  static const _photoTriggerCount = 2;

  bool _loaded = false;
  DateTime? _lastShown;
  String _shownTodayDate = '';
  int _photoCountTriggered = 0;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_lastShownIsoKey);
      _lastShown = iso == null ? null : DateTime.tryParse(iso);
      _shownTodayDate = prefs.getString(_shownTodayDateKey) ?? '';
      _photoCountTriggered = prefs.getInt(_photoCountTriggeredKey) ?? 0;
    } catch (_) {/* no-op */}
    _loaded = true;
  }

  /// Returns true if we should pop the paywall RIGHT NOW given the
  /// trigger that just fired. Caller is responsible for actually
  /// showing it and then calling [markShown].
  ///
  /// [trigger] is one of:
  ///   'photo'     — user just logged a photo
  ///   'recipe'    — Caliana just delivered a recipe pull
  ///   'app_open'  — app entered foreground
  ///   'plan_open' — user opened the Plan tab
  bool shouldShowOpportunistic(String trigger) {
    if (UsageService.instance.isPro) return false;
    if (!_loaded) return false;

    // Hard cooldown — never two pops in the same 6h window.
    if (_lastShown != null) {
      final hoursSince = DateTime.now().difference(_lastShown!).inHours;
      if (hoursSince < _cooldownHours) return false;
    }

    final inTrial = UsageService.instance.isInGiftTrial;
    final today = _todayKey();

    // In-trial logic
    if (inTrial) {
      switch (trigger) {
        case 'photo':
          // First fire after _photoTriggerCount cumulative photos.
          final totalPhotos = UsageService.instance.totalPhotos;
          if (totalPhotos >= _photoTriggerCount &&
              _photoCountTriggered < _photoTriggerCount) {
            return true;
          }
          return false;
        case 'recipe':
          // Fire after a recipe pull on day 2 / 3 — value moment.
          final daysLeft = UsageService.instance.giftTrialDaysLeft;
          if (daysLeft <= 2 && _shownTodayDate != today) return true;
          return false;
        case 'app_open':
          // On day 2 + day 3, surface once per day on app open.
          final daysLeft = UsageService.instance.giftTrialDaysLeft;
          if (daysLeft <= 2 && _shownTodayDate != today) return true;
          return false;
        default:
          return false;
      }
    }

    // Post-trial: surface once per calendar day on app_open or first
    // action so the conversion moment stays top-of-mind without
    // hijacking every interaction.
    if (trigger == 'app_open' || trigger == 'photo' || trigger == 'recipe') {
      if (_shownTodayDate != today) return true;
    }
    return false;
  }

  /// Persist that the paywall was just surfaced. Call after the
  /// PaywallScreen pops (from any trigger path).
  Future<void> markShown() async {
    final now = DateTime.now();
    _lastShown = now;
    _shownTodayDate = _todayKey();
    _photoCountTriggered = UsageService.instance.totalPhotos;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastShownIsoKey, now.toIso8601String());
      await prefs.setString(_shownTodayDateKey, _shownTodayDate);
      await prefs.setInt(_photoCountTriggeredKey, _photoCountTriggered);
    } catch (_) {/* no-op */}
  }

  String _todayKey() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }
}
