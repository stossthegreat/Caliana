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
/// One offering, two products: monthly (with 7-day free trial) and
/// annual. Single entitlement: `pro`. Wired to RevenueCat — purchases
/// flow through Purchases.purchasePackage, the customer-info listener
/// in RevenueCatService syncs the local Pro flag.
///
/// All legal links point at the GitHub Pages site so reviewers (and
/// users) can read them without leaving the app.
class PaywallScreen extends StatefulWidget {
  final String? triggerText;
  const PaywallScreen({super.key, this.triggerText});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
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

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView(widget.triggerText ?? 'manual');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showClose = true);
    });
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    final svc = RevenueCatService.instance;
    if (!svc.ready) {
      // Try once — might not have finished bootstrapping yet.
      await svc.bootstrap();
    }
    if (svc.currentOffering == null) {
      await svc.refreshOffering();
    }
    final offering = svc.currentOffering;
    if (offering == null || !mounted) {
      // Show the screen with placeholder pricing — user can still
      // read the copy and tap Restore. Real prices appear once the
      // offering loads (e.g. when RC API key is set in CI).
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
      // Default selection: monthly (because it carries the 7-day
      // trial — the headline pitch). User can flip to annual.
      _selected = _monthly ?? _annual;
    });
  }

  String get _ctaLabel {
    if (_busy) return 'Working…';
    final pkg = _selected;
    if (pkg == null) {
      return 'Start 7-day free trial';
    }
    final priceString = pkg.storeProduct.priceString;
    if (pkg.packageType == PackageType.monthly) {
      return 'Start 7-day free trial';
    }
    if (pkg.packageType == PackageType.annual) {
      return 'Subscribe — $priceString / year';
    }
    return 'Subscribe — $priceString';
  }

  String _selectedDisclosure() {
    final pkg = _selected;
    if (pkg == null) {
      return '7-day free trial, then a recurring subscription. Auto-renews '
          'unless cancelled at least 24 hours before the period ends. '
          'Cancel any time in your store account settings.';
    }
    final price = pkg.storeProduct.priceString;
    if (pkg.packageType == PackageType.monthly) {
      return '7-day free trial, then $price billed every month. '
          "You won't be charged during the trial — cancel any time in "
          "your store account at least 24 hours before the trial ends "
          "and you'll pay nothing. After the trial, the subscription "
          'auto-renews monthly until you cancel.';
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
                const SizedBox(height: 18),
                _hero(),
                const SizedBox(height: 14),
                _features(),
                const SizedBox(height: 22),
                if (_monthly != null || _annual != null)
                  _priceRow()
                else
                  _priceSkeleton(),
                const SizedBox(height: 16),
                _cta(),
                const SizedBox(height: 12),
                _disclosure(),
                const SizedBox(height: 10),
                _legalRow(),
                const SizedBox(height: 6),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.surfaceBorder,
                width: 1,
              ),
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
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Unlimited everything. Try 7 days free.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _features() {
    return Column(
      children: const [
        _Feature(
          icon: Icons.all_inclusive_rounded,
          title: 'Unlimited everything',
          sub: 'Photo logs, voice replies, recipe pulls, plan rebuilds. No counters, no caps.',
        ),
        SizedBox(height: 10),
        _Feature(
          icon: Icons.calendar_view_week_rounded,
          title: 'Multi-day rebuild plans',
          sub: 'Go over today, she fixes tomorrow automatically.',
        ),
        SizedBox(height: 10),
        _Feature(
          icon: Icons.record_voice_over_rounded,
          title: 'Caliana speaks back',
          sub: 'British voice replies via ElevenLabs.',
        ),
        SizedBox(height: 10),
        _Feature(
          icon: Icons.bolt_rounded,
          title: 'Priority models',
          sub: 'GPT-4o vision for photos, Whisper for voice, the lot.',
        ),
      ],
    );
  }

  Widget _priceRow() {
    return Row(
      children: [
        Expanded(
          child: _priceCard(
            package: _monthly,
            label: 'Monthly',
            sub: '/month',
            badge: '7-DAY FREE TRIAL',
            isSelected: _selected == _monthly && _monthly != null,
            onTap: _monthly == null
                ? null
                : () => setState(() => _selected = _monthly),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _priceCard(
            package: _annual,
            label: 'Annual',
            sub: '/year',
            badge: 'BEST VALUE',
            isSelected: _selected == _annual && _annual != null,
            onTap: _annual == null
                ? null
                : () => setState(() => _selected = _annual),
          ),
        ),
      ],
    );
  }

  Widget _priceSkeleton() {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      child: Center(
        child: Text(
          'Loading prices…',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textHint,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _priceCard({
    required Package? package,
    required String label,
    required String sub,
    required String badge,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    final priceText = package?.storeProduct.priceString ?? '—';
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 116,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              badge,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 0.6,
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
      height: 58,
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
                      blurRadius: 24,
                      offset: const Offset(0, 6),
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
                      fontWeight: FontWeight.w800,
                      color: canBuy
                          ? Colors.white
                          : AppColors.textHint,
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
          fontSize: 12,
          height: 1.45,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
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

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

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
        // Cancelled by user — nothing to do.
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
            fontWeight: FontWeight.w600,
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

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _Feature({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
