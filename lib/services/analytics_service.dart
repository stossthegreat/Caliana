/// No-op analytics. Firebase removed; we keep this stub so call sites
/// elsewhere in the app don't have to change. Each method just logs to
/// debug console — swap in a real provider here later if we ever add one.
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  void _log(String name, [Map<String, Object?>? params]) {
    if (params == null || params.isEmpty) {
      debugPrint('📊 $name');
    } else {
      debugPrint('📊 $name $params');
    }
  }

  Future<void> logAppOpen() async => _log('app_open');

  Future<void> logOnboardingStep(int step, String label) async =>
      _log('onboarding_step', {'step': step, 'label': label});

  Future<void> logOnboardingComplete({
    required String tone,
    required String goalType,
    required int dailyKcal,
  }) async =>
      _log('onboarding_complete', {
        'tone': tone,
        'goal_type': goalType,
        'daily_kcal': dailyKcal,
      });

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
        'is_interjection': isInterjection.toString(),
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
}
