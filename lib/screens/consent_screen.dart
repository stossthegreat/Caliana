import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/consent_service.dart';
import '../theme/app_theme.dart';

/// First-run AI data-sharing consent screen.
///
/// Required by Apple App Store Review Guidelines 5.1.1(i) and 5.1.2(i)
/// for apps that share personal data with third-party AI services. Names
/// the recipients (OpenAI, ElevenLabs), describes the data, and only
/// stores Granted state once the user explicitly accepts.
///
/// User can decline — app then falls back to local-only mode. They can
/// re-enable from Settings at any time.
class ConsentScreen extends StatelessWidget {
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const ConsentScreen({
    super.key,
    required this.onAccepted,
    required this.onDeclined,
  });

  static const _privacyUrl = 'https://caliana.app/privacy.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Before we start',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Caliana uses AI services to read your food photos, "
                        "transcribe your voice, generate her replies, and "
                        "voice them. We need your permission first.",
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _serviceCard(
                        icon: Icons.auto_awesome_rounded,
                        name: 'OpenAI',
                        purpose: 'Chat replies, food / fridge photo '
                            'analysis, voice transcription.',
                        sent: 'Typed messages, photos you snap, recorded '
                            'audio when you use voice input.',
                      ),
                      const SizedBox(height: 12),
                      _serviceCard(
                        icon: Icons.graphic_eq_rounded,
                        name: 'ElevenLabs',
                        purpose: "Synthesises Caliana's voice when she "
                            "replies aloud.",
                        sent: "Caliana's reply text only. Your voice "
                            'is never sent to ElevenLabs.',
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'You stay in control',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "We don't sell your data. You can revoke "
                              "permission any time in Settings, and you "
                              "can delete your data from the app in one "
                              "tap. Photos and audio are sent only when "
                              "you actively use those features.",
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final uri = Uri.tryParse(_privacyUrl);
                            if (uri != null) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: const Text(
                            'Read the full privacy policy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _primaryButton(
                label: 'I agree — let Caliana do her thing',
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ConsentService.instance.grant();
                  onAccepted();
                },
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDeclined();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Not now",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceCard({
    required IconData icon,
    required String name,
    required String purpose,
    required String sent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  purpose,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Data sent: $sent',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
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
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
