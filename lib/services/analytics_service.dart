/// Anonymous analytics for Caliana — Firebase-backed, no sign-in required.
///
/// Firebase Analytics auto-generates a per-install `app_instance_id` the
/// moment the app boots. That id is the unit of analysis: one id =
/// one install. We never see / store / send a name, email, phone, IP,
/// or any other PII. Pseudonymous by design — the same model every
/// non-logged-in app uses (Spotify free tier, Reddit guest, etc).
///
/// Wiring:
///   • main.dart calls Firebase.initializeApp() and stores firebaseReady
///   • AnalyticsService methods always succeed — they no-op silently if
///     Firebase didn't initialise (e.g. on web previews or if the
///     GoogleService-Info.plist / google-services.json files are
///     missing in a fresh CI environment).
///   • Each method here mirrors a real product event so the dashboard
///     reads as user behaviour, not raw screen names.
///
/// To turn this on for shipped builds you need ONE thing per platform:
///   • iOS: drop `ios/Runner/GoogleService-Info.plist` from the
///     Firebase Console → Project settings → iOS app config.
///   • Android: drop `android/app/google-services.json` from the same
///     console → Android app config.
///   The dart side here doesn't change — once those files are in the
///   build, the same _log() calls below start populating Firebase.
library;

import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Lazily resolved. Returns null if Firebase didn't initialise — every
  /// log method then no-ops silently rather than throwing.
  FirebaseAnalytics? get _fa {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Optional: navigator observer to tie screen-views to a session.
  /// Wire by adding to MaterialApp.navigatorObservers if you want
  /// auto screen tracking. Returns null when Firebase isn't ready.
  FirebaseAnalyticsObserver? get observer {
    final fa = _fa;
    if (fa == null) return null;
    return FirebaseAnalyticsObserver(analytics: fa);
  }

  Future<void> _log(String name, [Map<String, Object?>? params]) async {
    final fa = _fa;
    if (fa == null) {
      // Firebase not configured — log to debug console so dev still sees
      // the event flow, but don't surface an error.
      if (params == null || params.isEmpty) {
        debugPrint('📊 (no-firebase) $name');
      } else {
        debugPrint('📊 (no-firebase) $name $params');
      }
      return;
    }
    try {
      // FirebaseAnalytics.logEvent only accepts non-null primitives in
      // params, so strip null values before forwarding.
      final clean = <String, Object>{};
      if (params != null) {
        params.forEach((k, v) {
          if (v != null) clean[k] = v;
        });
      }
      await fa.logEvent(name: name, parameters: clean);
    } catch (e) {
      debugPrint('📊 analytics log failed ($name): $e');
    }
  }

  /// Optional: tag the install with a non-PII property (e.g. tone preset)
  /// so dashboards can segment Polite vs Cheeky vs Savage cohorts. Never
  /// pass anything that could identify a person.
  Future<void> setProperty(String key, String? value) async {
    try {
      await _fa?.setUserProperty(name: key, value: value);
    } catch (e) {
      debugPrint('📊 set property failed ($key): $e');
    }
  }

  // ---- product events --------------------------------------------------

  Future<void> logAppOpen() async => _log('app_open');

  Future<void> logOnboardingStep(int step, String label) async =>
      _log('onboarding_step', {'step': step, 'label': label});

  Future<void> logOnboardingComplete({
    required String tone,
    required String goalType,
    required int dailyKcal,
  }) async {
    await _log('onboarding_complete', {
      'tone': tone,
      'goal_type': goalType,
      'daily_kcal': dailyKcal,
    });
    // Tag the install with persona + goal so we can segment cohorts.
    await setProperty('tone', tone);
    await setProperty('goal_type', goalType);
  }

  Future<void> logFoodLog({
    required String inputMethod,
    required int calories,
    required String confidence,
  }) async =>
      _log('food_log', {
        'input_method': inputMethod,
        'calories': calories,
        'confidence': confidence,
      });

  Future<void> logFoodLogDeleted(String inputMethod) async =>
      _log('food_log_deleted', {'input_method': inputMethod});

  Future<void> logCalianaMessage({
    required bool isInterjection,
    required String trigger,
  }) async =>
      _log('caliana_message', {
        'is_interjection': isInterjection ? 1 : 0,
        'trigger': trigger,
      });

  Future<void> logCalianaVoicePlayed() async => _log('caliana_voice_played');

  Future<void> logRebuildPlanAccepted({required int daysToRebuild}) async =>
      _log('rebuild_plan_accepted', {'days': daysToRebuild});

  Future<void> logPaywallView(String trigger) async =>
      _log('paywall_view', {'trigger': trigger});

  Future<void> logPaywallSubscribeAttempt(bool annual) async =>
      _log('paywall_subscribe_attempt', {'plan': annual ? 'annual' : 'monthly'});

  Future<void> logShareRecap() async => _log('share_recap');

  Future<void> logRatingSubmit(int stars) async =>
      _log('rating_submit', {'stars': stars});

  // RevenueCat purchase event — fired from RevenueCatService on a
  // successful entitlement transition so the funnel closes in Firebase
  // even if you don't pay for RevenueCat's own dashboard.
  Future<void> logSubscribeSuccess({required bool annual}) async =>
      _log('subscribe_success', {'plan': annual ? 'annual' : 'monthly'});
}
