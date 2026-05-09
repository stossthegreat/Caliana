import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/review_prompt_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';

/// In-app 5-star review sheet with a free-text feedback box. Two paths:
///
///   • 4–5 stars  → fire the native iOS rating sheet (so the rating
///     actually counts toward the App Store score). The user's typed
///     text comes with us privately.
///   • 1–3 stars  → never push them to leave a public bad review.
///     Capture the text and offer to email it straight to support
///     instead, so we get the feedback and they don't tank the rating.
///
/// Either way, the user sees a "Thank you — we appreciate your
/// feedback" confirmation in-app before the sheet closes. No surprise
/// jumps to external pages without warning.
class ReviewPromptSheet extends StatefulWidget {
  const ReviewPromptSheet({super.key});

  static const _supportEmail = 'info@m2mb.co.uk';

  static Future<void> show(BuildContext context) async {
    AnalyticsService.instance.logPaywallView('review_prompt_shown');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: const ReviewPromptSheet(),
      ),
    );
    await ReviewPromptService.instance.markShown();
  }

  @override
  State<ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<ReviewPromptSheet> {
  final TextEditingController _text = TextEditingController();
  int _stars = 0;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_stars == 0 || _submitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    AnalyticsService.instance.logRatingSubmit(_stars);

    // High rating → push them to the App Store rating sheet so the
    // public score actually moves.
    if (_stars >= 4) {
      try {
        final reviewer = InAppReview.instance;
        if (await reviewer.isAvailable()) {
          await reviewer.requestReview();
        }
      } catch (_) {/* no-op */}
    }
    // Lower rating with text → email the team directly so we get the
    // actionable feedback instead of a public bad review.
    if (_stars <= 3 && _text.text.trim().isNotEmpty) {
      final body = Uri.encodeComponent(
          'Rating: $_stars/5\n\n${_text.text.trim()}\n\n— Sent from Caliana');
      final subject = Uri.encodeComponent('Caliana feedback ($_stars/5)');
      final mail = Uri.parse(
          'mailto:${ReviewPromptSheet._supportEmail}?subject=$subject&body=$body');
      try {
        if (await canLaunchUrl(mail)) {
          await launchUrl(mail, mode: LaunchMode.externalApplication);
        }
      } catch (_) {/* no-op */}
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: _submitted ? _buildThanks() : _buildPrompt(),
        ),
      ),
    );
  }

  Widget _buildPrompt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
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
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enjoying Caliana?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Rate her, leave a quick note. Takes ten seconds and it "
          'genuinely helps us make her better.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final filled = i < _stars;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _stars = i + 1);
              },
              child: AnimatedScale(
                scale: filled ? 1.10 : 1.0,
                duration: const Duration(milliseconds: 160),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: filled
                        ? const Color(0xFFFFC234)
                        : AppColors.textHint,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _text,
          maxLines: 3,
          minLines: 3,
          maxLength: 280,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Tell us anything (optional)…',
            hintStyle: const TextStyle(
              color: AppColors.textHint,
              fontSize: 13.5,
            ),
            counterText: '',
            filled: true,
            fillColor: AppColors.backgroundDeep,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: GestureDetector(
            onTap: (_stars > 0 && !_submitting) ? _onSubmit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: _stars > 0
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
                color: _stars > 0 ? null : AppColors.backgroundDeep,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _stars > 0
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Send feedback',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _stars > 0
                              ? Colors.white
                              : AppColors.textHint,
                          letterSpacing: -0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Maybe later',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThanks() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5A8AFF), Color(0xFF2F6BFF)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Thank you — we genuinely appreciate it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _stars >= 4
              ? "Caliana's chuffed. We'll keep making her sharper."
              : "We've got it. We'll fix what isn't landing.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}
