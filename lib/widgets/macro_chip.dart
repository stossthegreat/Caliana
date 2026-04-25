import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// One macro widget — protein, carbs, or fat.
/// Compact glass chip with an emoji, current/target grams, and a thin progress bar.
class MacroChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int current;
  final int target;
  final Color color;
  final VoidCallback? onTap;

  const MacroChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.5);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: GlassDecoration.card(opacity: 0.05, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$current',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: '/${target}g',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => Stack(
                  children: [
                    Container(
                      height: 4,
                      width: double.infinity,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.6),
                              color,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
