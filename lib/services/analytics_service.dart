import 'package:firebase_analytics/firebase_analytics.dart';

/// Caliana's analytics. Slim event surface — only what we'll actually look at.
///
/// Every accessor and method is fail-safe: if Firebase has not been
/// initialised (e.g. the iOS bundle hasn't been registered in the Firebase
/// console yet, so there's no GoogleService-Info.plist), accessing
/// `FirebaseAnalytics.instance` throws. We must never let that throw
/// propagate up, otherwise it kills the calling tap-handler — which is
/// exactly what made the Continue button "unresponsive" on iPad in
/// Apple's review (Submission ID d81df97a). Lazy + try/catch everywhere.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Cached client — null until first successful access. Re-attempted on
  /// every call so analytics start working as soon as Firebase finishes
  /// initialising mid-session.
  static FirebaseAnalytics? _cached;
  FirebaseAnalytics? get _safe {
    if (_cached != null) return _cached;
    try {
      _cached = FirebaseAnalytics.instance;
      return _cached;
    } catch (_) {
      return null;
    }
  }

  /// Returns null if Firebase isn't ready — callers must check
  /// `firebaseReady` before wiring this into MaterialApp.navigatorObservers.
  FirebaseAnalyticsObserver? get observer {
    final a = _safe;
    if (a == null) return null;
    return FirebaseAnalyticsObserver(analytics: a);
  }

  // ----- core lifecycle -----

  Future<void> logAppOpen() async {
    try { await _safe?.logAppOpen(); } catch (_) {}
  }

  Future<void> logOnboardingStep(int step, String label) async {
    try {
      await _safe?.logEvent(
        name: 'onboarding_step',
        parameters: {'step': step, 'label': label},
      );
    } catch (_) {}
  }

  Future<void> logOnboardingComplete({
    required String tone,
    required String goalType,
    required int dailyKcal,
  }) async {
    try {
      await _safe?.logEvent(
        name: 'onboarding_complete',
        parameters: {
          'tone': tone,
          'goal_type': goalType,
          'daily_kcal': dailyKcal,
        },
      );
    } catch (_) {}
  }

  // ----- food log events -----

  Future<void> logFoodLog({
    required String inputMethod,
    required int calories,
    required String confidence,
  }) async {
    try {
      await _safe?.logEvent(
        name: 'food_log',
        parameters: {
          'input_method': inputMethod,
          'calories': calories,
          'confidence': confidence,
        },
      );
    } catch (_) {}
  }

  Future<void> logFoodLogDeleted(String inputMethod) async {
    try {
      await _safe?.logEvent(
        name: 'food_log_deleted',
        parameters: {'input_method': inputMethod},
      );
    } catch (_) {}
  }

  // ----- caliana chat events -----

  Future<void> logCalianaMessage({
    required bool isInterjection,
    required String trigger,
  }) async {
    try {
      await _safe?.logEvent(
        name: 'caliana_message',
        parameters: {
          'is_interjection': isInterjection.toString(),
          'trigger': trigger,
        },
      );
    } catch (_) {}
  }

  Future<void> logCalianaVoicePlayed() async {
    try { await _safe?.logEvent(name: 'caliana_voice_played'); } catch (_) {}
  }

  Future<void> logRebuildPlanAccepted({required int daysToRebuild}) async {
    try {
      await _safe?.logEvent(
        name: 'rebuild_plan_accepted',
        parameters: {'days': daysToRebuild},
      );
    } catch (_) {}
  }

  // ----- paywall -----

  Future<void> logPaywallView(String trigger) async {
    try {
      await _safe?.logEvent(
        name: 'paywall_view',
        parameters: {'trigger': trigger},
      );
    } catch (_) {}
  }

  Future<void> logPaywallSubscribeAttempt(bool annual) async {
    try {
      await _safe?.logEvent(
        name: 'paywall_subscribe_attempt',
        parameters: {'plan': annual ? 'annual' : 'monthly'},
      );
    } catch (_) {}
  }

  // ----- share -----

  Future<void> logShareRecap() async {
    try { await _safe?.logEvent(name: 'share_recap'); } catch (_) {}
  }

  // ----- ratings -----

  Future<void> logRatingSubmit(int stars) async {
    try {
      await _safe?.logEvent(
        name: 'rating_submit',
        parameters: {'stars': stars},
      );
    } catch (_) {}
  }
}
