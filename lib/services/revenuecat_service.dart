import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'usage_service.dart';

/// Caliana's subscription gateway.
///
/// One entitlement: `pro` (lowercase). One offering, with two
/// products: monthly (with a 7-day free trial) and annual.
///
/// Configure once on app boot via [bootstrap]. Purchases / restores
/// route through the in-app paywall; whenever the customer info
/// changes, [_syncEntitlement] mirrors RevenueCat's `pro` entitlement
/// state to UsageService so every gate in the app stays in sync.
///
/// Public RevenueCat API keys are SAFE to ship in the binary. They
/// must come from your RevenueCat dashboard (one Apple key, one
/// Google key). Provide them at build time:
///
///   --dart-define=RC_IOS_KEY=appl_xxxxxxxx
///   --dart-define=RC_ANDROID_KEY=goog_xxxxxxxx
///
/// or set them in this file's defaults if you'd rather hardcode.
class RevenueCatService {
  RevenueCatService._();
  static final RevenueCatService instance = RevenueCatService._();

  /// The single entitlement identifier configured in the RevenueCat
  /// dashboard. All "is the user Pro" checks key off this.
  static const String entitlementId = 'pro';

  static const _iosApiKey = String.fromEnvironment(
    'RC_IOS_KEY',
    defaultValue: '',
  );
  static const _androidApiKey = String.fromEnvironment(
    'RC_ANDROID_KEY',
    defaultValue: '',
  );

  bool _ready = false;
  Offering? _currentOffering;

  bool get ready => _ready;
  bool get hasOffering => _currentOffering != null;
  Offering? get currentOffering => _currentOffering;

  /// One-shot init. No-ops if no API key is set so the app still
  /// boots in dev without a configured RC project.
  Future<void> bootstrap() async {
    if (_ready) return;
    final key = Platform.isIOS ? _iosApiKey : _androidApiKey;
    if (key.isEmpty) {
      debugPrint(
        '🛒 RevenueCat: no API key (RC_IOS_KEY / RC_ANDROID_KEY). '
        'Skipping init — paywall will run in offline mode.',
      );
      return;
    }
    try {
      await Purchases.setLogLevel(
        kReleaseMode ? LogLevel.warn : LogLevel.info,
      );
      await Purchases.configure(PurchasesConfiguration(key));
      _ready = true;
      Purchases.addCustomerInfoUpdateListener(_syncEntitlement);
      // Fire once so the local Pro flag is correct on first launch
      // for returning users.
      try {
        final info = await Purchases.getCustomerInfo();
        await _syncEntitlement(info);
      } catch (e) {
        debugPrint('🛒 RevenueCat customer info fetch failed: $e');
      }
      // Eagerly load the default offering so the paywall opens fast.
      await refreshOffering();
    } catch (e) {
      debugPrint('🛒 RevenueCat configure failed: $e');
    }
  }

  Future<void> refreshOffering() async {
    if (!_ready) return;
    try {
      final offerings = await Purchases.getOfferings();
      _currentOffering = offerings.current;
      if (_currentOffering == null) {
        debugPrint(
          '🛒 RevenueCat: no current offering. Configure a default '
          'offering in the dashboard with two products (monthly w/ '
          '7-day trial, annual).',
        );
      }
    } catch (e) {
      debugPrint('🛒 RevenueCat offerings fetch failed: $e');
    }
  }

  /// Buy a specific package. Returns true on success, throws on
  /// genuine purchase failure (caller surfaces the message). User
  /// cancellation returns false silently.
  Future<bool> purchase(Package package) async {
    if (!_ready) {
      throw StateError('RevenueCat not configured');
    }
    try {
      final result = await Purchases.purchasePackage(package);
      await _syncEntitlement(result);
      return result.entitlements.active.containsKey(entitlementId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  /// Bring back an existing entitlement on a fresh install / new
  /// device. Returns true if Pro is now active.
  Future<bool> restore() async {
    if (!_ready) return false;
    try {
      final info = await Purchases.restorePurchases();
      await _syncEntitlement(info);
      return info.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      debugPrint('🛒 RevenueCat restore failed: $e');
      return false;
    }
  }

  Future<void> _syncEntitlement(CustomerInfo info) async {
    final isPro = info.entitlements.active.containsKey(entitlementId);
    if (UsageService.instance.isPro != isPro) {
      await UsageService.instance.setPro(isPro);
    }
  }
}
