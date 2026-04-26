import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../services/revenuecat_service.dart';
import '../widgets/aurora_background.dart';

/// Caliana Pro paywall — one static page.
///
/// Whole sell fits on a single screen: hero, four feature rows, two
/// identical price cards (monthly + annual), CTA, and a small fixed-
/// height inner-scrollable area for Apple's required disclosure and
/// legal links. Nothing else scrolls.
class PaywallScreen extends StatefulWidget {
  final String? triggerText;
  const PaywallScreen({super.key, this.triggerText});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
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
    if (offering == null || !mounted) return;
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
    if (pkg == null) return 'Start 7-day free trial';
    final price = pkg.storeProduct.priceString;
    if (_hasIntroTrial(pkg)) return 'Start 7-day free trial';
    if (pkg.packageType == PackageType.annual) return 'Continue — $price / yr';
    if (pkg.packageType == PackageType.monthly) return 'Continue — $price / mo';
    return 'Continue — $price';
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(),
                const SizedBox(height: 6),
                _hero(),
                const SizedBox(height: 14),
                _features(),
                const Spacer(),
                _priceRow(),
                const SizedBox(height: 12),
                _cta(),
                const SizedBox(height: 8),
                _legalArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 32,
      child: Align(
        alignment: Alignment.centerRight,
        child: AnimatedOpacity(
          opacity: _showClose ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: GestureDetector(
            onTap: _showClose ? () => Navigator.pop(context) : null,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder, width: 1),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Column(
      children: [
        Image.asset(
          'assets/caliana.png',
          width: 84,
          height: 84,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        const Text(
          'Caliana Pro',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Unlimited everything. Annual: 7 days free.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.3,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _features() {
    const items = [
      _FeatureSpec(
        icon: Icons.all_inclusive_rounded,
        title: 'Unlimited everything',
        sub: 'Photos, voice, recipes — no caps.',
      ),
      _FeatureSpec(
        icon: Icons.auto_awesome_rounded,
        title: 'She fixes bad days',
        sub: 'Tomorrow rebuilds itself when today goes off.',
      ),
      _FeatureSpec(
        icon: Icons.record_voice_over_rounded,
        title: 'British voice replies',
        sub: 'Hear Caliana out loud, on demand.',
      ),
      _FeatureSpec(
        icon: Icons.bolt_rounded,
        title: 'Priority models',
        sub: 'GPT-4o vision, Whisper, the lot.',
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _AnimatedFeatureRow(
            spec: items[i],
            controller: _featuresCtrl,
            startAt: i * 0.16,
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
              subFallback: '/mo',
              badge: 'No commitment',
              isSelected: _selected == _monthly && _monthly != null,
              isPlaceholder: _monthly == null,
              onTap: _monthly == null
                  ? null
                  : () => setState(() => _selected = _monthly),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _priceCard(
              package: _annual,
              label: 'ANNUAL',
              priceFallback: '£29.99',
              subFallback: '/yr',
              badge: _hasIntroTrial(_annual) ? '7 DAYS FREE' : 'BEST VALUE',
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
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 116,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    priceText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isPlaceholder
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    subFallback,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isHighlight
                    ? AppColors.primary
                    : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: isHighlight ? Colors.white : AppColors.primary,
                  letterSpacing: 0.5,
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
      height: 54,
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: canBuy
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.40),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _ctaLabel,
                    style: TextStyle(
                      fontSize: 15.5,
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

  /// Tiny scroll area at the bottom — exists only so the Apple-required
  /// auto-renew disclosure and legal links can be read without bloating
  /// the page above. Capped at 78pt.
  Widget _legalArea() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 78),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Text(
              _selectedDisclosure(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                _legalLink('Restore', _restorePurchase),
                _dot(),
                _legalLink('Terms', () => _openUrl(_termsUrl)),
                _dot(),
                _legalLink('Privacy', () => _openUrl(_privacyUrl)),
                _dot(),
                _legalLink('Delete', () => _openUrl(_deleteUrl)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
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
          const SnackBar(content: Text('Restored. Caliana Pro is back on.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nothing to restore on this account.")),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        '·',
        style: TextStyle(fontSize: 12, color: AppColors.textHint),
      ),
    );
  }
}

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

/// Compact feature row — gradient icon tile + title + one-line sub.
/// No card chrome (the old version was eating vertical space). Fades
/// + slides in on a staggered offset of the parent controller.
class _AnimatedFeatureRow extends StatelessWidget {
  final _FeatureSpec spec;
  final AnimationController controller;
  final double startAt;
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
            offset: Offset(0, (1 - curve.value) * 10),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(spec.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spec.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    spec.sub,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
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
