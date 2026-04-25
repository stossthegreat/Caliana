import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Calorie ring — color shifts from blue (under) → amber (close) →
/// coral (over). Number lives INSIDE the ring. Has an [onDark] mode
/// for placement on coloured backgrounds (white text + light track).
class CalorieRing extends StatefulWidget {
  final int consumed;
  final int goal;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final bool onDark;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.goal,
    this.label = 'today',
    this.onTap,
    this.onLongPress,
    this.size = 160,
    this.onDark = false,
  });

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing>
    with SingleTickerProviderStateMixin {
  late int _previousConsumed;

  @override
  void initState() {
    super.initState();
    _previousConsumed = widget.consumed;
  }

  @override
  void didUpdateWidget(covariant CalorieRing old) {
    super.didUpdateWidget(old);
    if (old.consumed != widget.consumed) {
      _previousConsumed = old.consumed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal == 0 ? 1 : widget.goal;
    final pct = widget.consumed / goal;
    final color = _ringColor(pct);
    final textColor =
        widget.onDark ? Colors.white : AppColors.textPrimary;
    final labelColor = widget.onDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textHint;
    final trackColor = widget.onDark
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.backgroundDeep;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: _previousConsumed / goal, end: pct),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _RingPainter(
                    progress: value.clamp(0.0, 1.2),
                    color: color,
                    trackColor: trackColor,
                  ),
                );
              },
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: _previousConsumed.toDouble(),
                    end: widget.consumed.toDouble(),
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    final shown = value.round();
                    final showLeft = widget.goal - shown;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showLeft.abs().toString(),
                          style: TextStyle(
                            fontSize: widget.size * 0.30,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -1.8,
                            height: 1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showLeft >= 0
                              ? widget.label.isEmpty
                                  ? 'left'
                                  : 'left ${widget.label}'
                              : widget.label.isEmpty
                                  ? 'over'
                                  : 'over ${widget.label}',
                          style: TextStyle(
                            fontSize: 10,
                            color: labelColor,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _ringColor(double pct) {
    if (widget.onDark) {
      // On a blue background: white-leaning fills, soft amber/coral when near/over.
      if (pct < 0.95) return Colors.white;
      if (pct < 1.10) return const Color(0xFFFFD580);
      return const Color(0xFFFFB4B6);
    }
    if (pct < 0.6) return AppColors.primary;
    if (pct < 0.95) return AppColors.warning;
    if (pct < 1.10) return AppColors.accent;
    return const Color(0xFFE53935);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  static const _strokeWidth = 10.0;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - _strokeWidth / 2 - 1;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final sweep = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
          colors: [
            color.withValues(alpha: 0.85),
            color,
            color.withValues(alpha: 1.0),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );

      if (progress > 1.0) {
        final overSweep = (progress - 1.0).clamp(0.0, 1.0) * 2 * math.pi;
        final overPaint = Paint()
          ..color = const Color(0xFFE53935)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - _strokeWidth - 4),
          -math.pi / 2,
          overSweep,
          false,
          overPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
