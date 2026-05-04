import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/usage_service.dart';
import '../services/analytics_service.dart';
import '../widgets/aurora_background.dart';

/// Caliana Pro paywall.
/// Blue throughout. App Store-compliant disclosures under the CTA.
class PaywallScreen extends StatefulWidget {
  final String? triggerText;
  const PaywallScreen({super.key, this.triggerText});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _showClose = false;
  bool _annual = true;

  // App Store legal links — replace with real ones when published.
  static const _termsUrl = 'https://stossthegreat.github.io/Caliana/terms.html';
  static const _privacyUrl = 'https://stossthegreat.github.io/Caliana/privacy.html';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logPaywallView(widget.triggerText ?? 'manual');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showClose = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          // Apple 4.0.0 fix: wrap in scroll view so legal links + CTA never
          // get cut off on shorter screens (iPad Air 11" was the offender).
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              children: [
                // Close (after 2s)
                Align(
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
                ),
                const SizedBox(height: 16),

                // Caliana with BLUE halo
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
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlock everything she can do.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),

                if (widget.triggerText != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
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

                const SizedBox(height: 22),
                _feature(
                    Icons.camera_alt_rounded, 'Unlimited photo logging'),
                const SizedBox(height: 12),
                _feature(
                    Icons.record_voice_over_rounded, 'Caliana speaks back'),
                const SizedBox(height: 12),
                _feature(
                    Icons.calendar_view_week_rounded,
                    'Multi-day rebuild plans'),
                const SizedBox(height: 12),
                _feature(Icons.menu_book_rounded, 'Save every meal she suggests'),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: _priceCard(
                        label: 'Monthly',
                        price: '\$5.99',
                        sub: '/month',
                        isSelected: !_annual,
                        onTap: () => setState(() => _annual = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _priceCard(
                        label: 'Annual',
                        price: '\$39.99',
                        sub: '/year',
                        // Apple 3.1.2(c) compliance: trial copy must be
                        // SUBORDINATE to the billed amount. Kept as a quiet
                        // grey caption (no bold, no brand colour, smaller font).
                        perDay: 'Includes 7-day free trial',
                        isSelected: _annual,
                        onTap: () => setState(() => _annual = true),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      AnalyticsService.instance
                          .logPaywallSubscribeAttempt(_annual);
                      // TODO: wire RevenueCat. For now flips Pro=true.
                      await UsageService.instance.setPro(true);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            "You're in. Caliana's yours.",
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppColors.backgroundElevated,
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF5A8AFF),
                            Color(0xFF2F6BFF),
                            Color(0xFF1F4FE0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.40),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      // Apple 3.1.2(c) compliance: the CTA leads with the
                      // BILLED AMOUNT. The trial mention lives only in the
                      // smaller subordinate caption below + the disclosure.
                      child: Center(
                        child: Text(
                          _annual
                              ? 'Subscribe — \$39.99 / year'
                              : 'Subscribe — \$5.99 / month',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // App Store-compliant disclosure (clearly legible)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _annual
                        ? '7-day free trial, then \$39.99 / year. Auto-renews '
                            'unless cancelled at least 24 hours before the trial '
                            'ends. Cancel any time in your App Store account '
                            'settings — your subscription continues until the '
                            'end of the current period.'
                        : 'Auto-renewing subscription, \$5.99 per month. '
                            'Renews automatically unless cancelled at least 24 '
                            'hours before the period ends. Cancel any time in '
                            'your App Store account settings.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legalLink('Restore purchase', _restorePurchase),
                    _dot(),
                    _legalLink('Terms', () => _openUrl(_termsUrl)),
                    _dot(),
                    _legalLink('Privacy', () => _openUrl(_privacyUrl)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Row(
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
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceCard({
    required String label,
    required String price,
    required String sub,
    String? badge,
    String? perDay,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 116,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primarySoft
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.surfaceBorder,
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
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
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
            if (perDay != null) ...[
              const SizedBox(height: 4),
              // Apple 3.1.2(c): trial / introductory copy must be subordinate
              // to the billed amount. Quiet grey, regular weight, smaller font
              // — clearly secondary to the $39.99 above.
              Text(
                perDay,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  Future<void> _restorePurchase() async {
    HapticFeedback.lightImpact();
    // TODO: restore purchases via RevenueCat
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restore: connect RevenueCat to enable.'),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
