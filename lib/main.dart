import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/today_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/consent_screen.dart';
import 'services/user_profile_service.dart';
import 'services/app_settings_service.dart';
import 'services/usage_service.dart';
import 'services/day_log_service.dart';
import 'services/saved_meals_service.dart';
import 'services/consent_service.dart';
import 'services/review_prompt_service.dart';
import 'services/analytics_service.dart';

void main() async {
  // Catch every framework error so the user never sees a red screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ FLUTTER ERROR: ${details.exception}');
    debugPrint('❌ STACK: ${details.stack}');
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      debugPrint('✅ Firebase initialized');
    } catch (e) {
      debugPrint('⚠️ Firebase init failed (analytics disabled): $e');
    }

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
      ConsentService.instance.load(),
      ReviewPromptService.instance.load(),
      OnboardingScreen.hasBeenSeen().then((v) => onboardingSeen = v),
    ]);
    debugPrint('✅ Caliana services loaded');

    if (firebaseReady) {
      try {
        AnalyticsService.instance.logAppOpen();
      } catch (_) {}
    }

    // Production: replace red error widgets with empty space.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('❌ Widget build error: ${details.exception}');
      return const SizedBox.shrink();
    };

    runApp(CalianaApp(
      showOnboarding: !onboardingSeen,
      firebaseReady: firebaseReady,
    ));
  } catch (e, stack) {
    debugPrint('❌ CRITICAL INIT CRASH: $e\n$stack');
    runApp(_FailsafeApp(error: e, stack: stack));
  }
}

class CalianaApp extends StatelessWidget {
  final bool showOnboarding;
  final bool firebaseReady;

  const CalianaApp({
    super.key,
    required this.showOnboarding,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (showOnboarding) {
      home = const _OnboardingGate();
    } else if (!ConsentService.instance.granted) {
      home = const _ConsentGate();
    } else {
      home = const TodayScreen();
    }
    return MaterialApp(
      title: 'Caliana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorObservers: () {
        if (!firebaseReady) return const <NavigatorObserver>[];
        final observer = AnalyticsService.instance.observer;
        return observer == null
            ? const <NavigatorObserver>[]
            : <NavigatorObserver>[observer];
      }(),
      home: home,
    );
  }
}

/// Shows onboarding once, then routes through consent if needed.
class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onComplete: () {
        final next = ConsentService.instance.granted
            ? const TodayScreen()
            : const _ConsentGate();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => next,
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

/// Apple 5.1.1(i) / 5.1.2(i) gate: shown after onboarding if the user has
/// not yet granted permission to send data to OpenAI / ElevenLabs. The
/// app cannot make AI-bound calls until consent is granted (or it falls
/// back to local-only behaviour from CalianaService).
class _ConsentGate extends StatelessWidget {
  const _ConsentGate();

  @override
  Widget build(BuildContext context) {
    void goHome() {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const TodayScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }

    return ConsentScreen(
      onAccepted: goHome,
      onDeclined: goHome,
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
