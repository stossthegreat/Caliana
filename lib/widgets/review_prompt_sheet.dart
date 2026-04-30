import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import '../services/review_prompt_service.dart';
import '../theme/app_theme.dart';

/// Beautiful 5-star review prompt. Shown once after the user logs a few
/// entries. Tapping any star fires the native iOS rating dialog (so the
/// review actually counts toward the App Store) and dismisses the sheet.
class ReviewPromptSheet extends StatefulWidget {
  const ReviewPromptSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const ReviewPromptSheet(),
    );
    await ReviewPromptService.instance.markShown();
  }

  @override
  State<ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<ReviewPromptSheet>
    with SingleTickerProviderStateMixin {
  int _hovered = 0;
  bool _submitting = false;

  Future<void> _onTap(int rating) async {
    if (_submitting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _hovered = rating;
      _submitting = true;
    });

    // Tiny delay so the user sees the stars light up before the system
    // dialog covers them — feels like the rating registered.
    await Future.delayed(const Duration(milliseconds: 380));

    final reviewer = InAppReview.instance;
    try {
      if (await reviewer.isAvailable()) {
        await reviewer.requestReview();
      } else {
        // Fallback: send them to the App Store write-review page.
        await reviewer.openStoreListing();
      }
    } catch (_) {
      // Swallow — we don't want a failed review prompt to crash the app.
    }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
              const SizedBox(height: 16),
              const Text(
                'Enjoying Caliana?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "If she's earning her keep, leave a quick review. "
                'Takes ten seconds and it genuinely helps the app.',
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
                  final filled = i < _hovered;
                  return GestureDetector(
                    onTap: () => _onTap(i + 1),
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
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      fontSize: 13,
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
}
