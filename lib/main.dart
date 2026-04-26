import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/main_tabs.dart';
import 'screens/onboarding_screen.dart';
import 'services/user_profile_service.dart';
import 'services/app_settings_service.dart';
import 'services/usage_service.dart';
import 'services/day_log_service.dart';
import 'services/saved_meals_service.dart';
import 'services/plan_service.dart';
import 'services/recovery_autopilot.dart';
import 'services/revenuecat_service.dart';
import 'services/analytics_service.dart';

void main() async {
  // Catch every framework error so the user never sees a red screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ FLUTTER ERROR: ${details.exception}');
    debugPrint('❌ STACK: ${details.stack}');
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    late final bool onboardingSeen;
    await Future.wait([
      UserProfileService.instance.load(),
      AppSettingsService.instance.load(),
      UsageService.instance.load(),
      DayLogService.instance.load(),
      SavedMealsService.instance.load(),
      PlanService.instance.load(),
      OnboardingScreen.hasBeenSeen().then((v) => onboardingSeen = v),
    ]);
    debugPrint('✅ Caliana services loaded');

    // Watch the day log — when it crosses an overage threshold, this
    // rebuilds tomorrow's plan in recovery mode automatically. The
    // user logs reality; she fixes the future.
    RecoveryAutopilot.instance.start();

    // Configure RevenueCat in the background — fire-and-forget so a
    // missing/bad API key never blocks the app from booting.
    unawaited(RevenueCatService.instance.bootstrap());

    AnalyticsService.instance.logAppOpen();

    // Production: replace red error widgets with empty space.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('❌ Widget build error: ${details.exception}');
      return const SizedBox.shrink();
    };

    runApp(CalianaApp(showOnboarding: !onboardingSeen));
  } catch (e, stack) {
    debugPrint('❌ CRITICAL INIT CRASH: $e\n$stack');
    runApp(_FailsafeApp(error: e, stack: stack));
  }
}

class CalianaApp extends StatelessWidget {
  final bool showOnboarding;

  const CalianaApp({
    super.key,
    required this.showOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caliana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: showOnboarding ? const _OnboardingGate() : const MainTabs(),
    );
  }
}

/// Shows onboarding once, then fades into the home screen.
class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onComplete: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainTabs(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
    );
  }
}

/// Last-resort UI shown only if app init crashes before MaterialApp can mount.
class _FailsafeApp extends StatelessWidget {
  final Object error;
  final StackTrace stack;
  const _FailsafeApp({required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caliana hit a bump',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  stack.toString().split('\n').take(15).join('\n'),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
