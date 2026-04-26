import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../services/revenuecat_service.dart';
import '../widgets/aurora_background.dart';

/// Caliana Pro paywall.
///
/// One offering, two products: monthly (no trial) and annual (with
/// the 7-day free trial). Single entitlement: `pro`. Wired to
/// RevenueCat — purchases flow through Purchases.purchasePackage; the
/// customer-info listener in RevenueCatService syncs the local Pro
/// flag.
///
/// Visual design: brand-blue everywhere, identically-sized monthly
/// + yearly cards, staggered fade-in for feature rows, placeholder
/// prices that look intentional (not "Loading…") while RevenueCat
/// fetches the live offering. All legal links route to the GitHub
/// Pages site so reviewers (and users) can read them in-app.
class PaywallScreen extends StatefulWidget {
  final String? triggerText;
  const PaywallScreen({super.key, this.triggerText});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with TickerProviderStateMixin {
  static const _termsUrl =
      'https://stossthegreat.github.io/Caliana/terms.html';
  static const _privacyUrl =
      'https://stossthegreat.github.io/Caliana/privacy.html';
  static const _deleteUrl =
      'https://stossthegreat.github.io/Caliana/delete-account.html';

  bool _showClose = false;
  bool _busy = false;
  String? _error;

  Package? _monthly;
  Package? _annual;
  Package? _selected;

  /// Stagger controller for the feature rows.
  late final AnimationController _featuresCtrl;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView(widget.triggerText ?? 'manual');
    _featuresCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showClose = true);
    });
    _loadOffering();
  }

  @override
  void dispose() {
    _featuresCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOffering() async {
    final svc = RevenueCatService.instance;
    if (!svc.ready) {
      await svc.bootstrap();
    }
    if (svc.currentOffering == null) {
      await svc.refreshOffering();
    }
    final offering = svc.currentOffering;
    if (offering == null || !mounted) {
      return;
    }
    setState(() {
      _monthly = offering.monthly ??
          offering.availablePackages
              .where((p) => p.packageType == PackageType.monthly)
              .cast<Package?>()
              .firstWhere((_) => true, orElse: () => null);
      _annual = offering.annual ??
          offering.availablePackages
              .where((p) => p.packageType == PackageType.annual)
              .cast<Package?>()
              .firstWhere((_) => true, orElse: () => null);
      // Default selection: ANNUAL — that's where the 7-day free trial
      // lives. Monthly is a no-trial option.
      _selected = _annual ?? _monthly;
    });
  }

  bool _hasIntroTrial(Package? p) {
    if (p == null) return false;
    return p.storeProduct.introductoryPrice != null;
  }

  String get _ctaLabel {
    if (_busy) return 'Working…';
    final pkg = _selected;
    if (pkg == null) {
      return 'Start 7-day free trial';
    }
    final priceString = pkg.storeProduct.priceString;
    if (_hasIntroTrial(pkg)) {
      return 'Start 7-day free trial';
    }
    if (pkg.packageType == PackageType.annual) {
      return 'Continue — $priceString / year';
    }
    if (pkg.packageType == PackageType.monthly) {
      return 'Continue — $priceString / month';
    }
    return 'Continue — $priceString';
  }

  String _selectedDisclosure() {
    final pkg = _selected;
    if (pkg == null) {
      return '7-day free trial on the annual plan, then a recurring '
          'subscription. Auto-renews unless cancelled at least 24 hours '
          'before the period ends. Cancel any time in your store account.';
    }
    final price = pkg.storeProduct.priceString;
    if (_hasIntroTrial(pkg)) {
      return '7-day free trial, then $price billed every year. '
          "You won't be charged during the trial — cancel any time in "
          "your store account at least 24 hours before the trial ends "
          "and you'll pay nothing. After the trial, the subscription "
          'auto-renews yearly until you cancel.';
    }
    if (pkg.packageType == PackageType.monthly) {
      return 'Auto-renewing subscription, $price billed every month. '
          'No free trial on monthly — switch to annual for the 7-day '
          'trial. Cancel any time in your store account at least 24 '
          'hours before the period ends.';
    }
    if (pkg.packageType == PackageType.annual) {
      return 'Auto-renewing subscription, $price billed every year. '
          'Renews automatically unless cancelled at least 24 hours '
          'before the period ends. Cancel any time in your store account.';
    }
    return 'Auto-renewing subscription. Cancel any time in your store '
        'account settings.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 14),
                _hero(),
                const SizedBox(height: 22),
                _features(),
                const SizedBox(height: 26),
                _priceRow(),
                const SizedBox(height: 18),
                _cta(),
                const SizedBox(height: 12),
                _disclosure(),
                const SizedBox(height: 8),
                _legalRow(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Align(
      alignment: Alignment.topRight,
      child: AnimatedOpacity(
        opacity: _showClose ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTap: _showClose ? () => Navigator.pop(context) : null,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surfaceBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 50,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/caliana.png',
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Caliana Pro',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.2,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Unlimited everything.\nAnnual: 7 days free.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        if (widget.triggerText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.triggerText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _features() {
    const items = [
      _FeatureSpec(
        icon: Icons.all_inclusive_rounded,
        title: 'Unlimited everything',
        sub: 'Photo logs, voice replies, recipe pulls, plan rebuilds — no caps.',
      ),
      _FeatureSpec(
        icon: Icons.calendar_view_week_rounded,
        title: 'Multi-day rebuild plans',
        sub: 'Go over today, she fixes tomorrow automatically.',
      ),
      _FeatureSpec(
        icon: Icons.record_voice_over_rounded,
        title: 'Caliana speaks back',
        sub: 'British voice replies through ElevenLabs.',
      ),
      _FeatureSpec(
        icon: Icons.bolt_rounded,
        title: 'Priority models',
        sub: 'GPT-4o vision for photos, Whisper for voice — the lot.',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AnimatedFeatureRow(
            spec: items[i],
            controller: _featuresCtrl,
            startAt: i * 0.18,
          ),
        ],
      ],
    );
  }

  Widget _priceRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _priceCard(
              package: _monthly,
              label: 'MONTHLY',
              priceFallback: '£4.99',
              subFallback: '/month',
              badge: 'Cancel any time',
              isSelected: _selected == _monthly && _monthly != null,
              isPlaceholder: _monthly == null,
              onTap: _monthly == null
                  ? null
                  : () => setState(() => _selected = _monthly),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _priceCard(
              package: _annual,
              label: 'ANNUAL',
              priceFallback: '£29.99',
              subFallback: '/year',
              badge: _hasIntroTrial(_annual)
                  ? '7 DAYS FREE'
                  : 'BEST VALUE',
              isSelected: _selected == _annual && _annual != null,
              isPlaceholder: _annual == null,
              isHighlight: true,
              onTap: _annual == null
                  ? null
                  : () => setState(() => _selected = _annual),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceCard({
    required Package? package,
    required String label,
    required String priceFallback,
    required String subFallback,
    required String badge,
    required bool isSelected,
    required bool isPlaceholder,
    bool isHighlight = false,
    required VoidCallback? onTap,
  }) {
    final priceText = package?.storeProduct.priceString ?? priceFallback;
    final subText = subFallback;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 152,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isHighlight
                    ? AppColors.primary.withValues(alpha: 0.30)
                    : AppColors.surfaceBorder),
            width: isSelected ? 1.8 : (isHighlight ? 1.2 : 1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (isHighlight)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceText,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isPlaceholder
                        ? AppColors.textHint
                        : AppColors.textPrimary,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    subText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isHighlight
                    ? AppColors.primary
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: isHighlight ? Colors.white : AppColors.primary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cta() {
    final canBuy = _selected != null && !_busy;
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: GestureDetector(
        onTap: canBuy ? _purchase : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: canBuy
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5A8AFF),
                      Color(0xFF2F6BFF),
                      Color(0xFF1F4FE0),
                    ],
                  )
                : null,
            color: canBuy ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(18),
            boxShadow: canBuy
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.40),
                      blurRadius: 26,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _ctaLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: canBuy ? Colors.white : AppColors.textHint,
                      letterSpacing: -0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _disclosure() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        _selectedDisclosure(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.5,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.05,
        ),
      ),
    );
  }

  Widget _legalRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _legalLink('Restore', _restorePurchase),
        _dot(),
        _legalLink('Terms', () => _openUrl(_termsUrl)),
        _dot(),
        _legalLink('Privacy', () => _openUrl(_privacyUrl)),
        _dot(),
        _legalLink('Delete account', () => _openUrl(_deleteUrl)),
      ],
    );
  }

  Future<void> _purchase() async {
    final pkg = _selected;
    if (pkg == null) return;
    HapticFeedback.mediumImpact();
    AnalyticsService.instance
        .logPaywallSubscribeAttempt(pkg.packageType == PackageType.annual);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await RevenueCatService.instance.purchase(pkg);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("You're in. Caliana's yours."),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: AppColors.backgroundElevated,
          ),
        );
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Purchase failed: $e';
      });
    }
  }

  Future<void> _restorePurchase() async {
    HapticFeedback.lightImpact();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final restored = await RevenueCatService.instance.restore();
      if (!mounted) return;
      setState(() => _busy = false);
      if (restored) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restored. Caliana Pro is back on.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nothing to restore on this account."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Restore failed: $e';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _legalLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

/// Static spec for a feature row — used by the paywall and onboarding
/// in the same shape so brand stays consistent.
class _FeatureSpec {
  final IconData icon;
  final String title;
  final String sub;
  const _FeatureSpec({
    required this.icon,
    required this.title,
    required this.sub,
  });
}

/// Feature row that fades + slides in on a staggered offset of the
/// parent controller. Polished, soft, fast — not the dead static
/// list the old paywall shipped.
class _AnimatedFeatureRow extends StatelessWidget {
  final _FeatureSpec spec;
  final AnimationController controller;
  final double startAt; // 0..1, where in the timeline this row begins
  const _AnimatedFeatureRow({
    required this.spec,
    required this.controller,
    required this.startAt,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(
        startAt.clamp(0.0, 1.0),
        (startAt + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curve.value) * 12),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(spec.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.sub,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
