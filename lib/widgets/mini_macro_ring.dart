import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Small macro ring — used in a row beside the big calorie ring.
/// Letter inside, grams below. Designed for blue (onDark) backgrounds.
class MiniMacroRing extends StatelessWidget {
  final String letter;
  final int current;
  final int target;
  final Color color;
  final double size;
  final bool onDark;

  const MiniMacroRing({
    super.key,
    required this.letter,
    required this.current,
    required this.target,
    required this.color,
    this.size = 52,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final txt = onDark ? Colors.white : const Color(0xFF0F172A);
    final label = onDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF6B7280);
    final track = onDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFEFF1F5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => CustomPaint(
                  size: Size(size, size),
                  painter: _MiniRingPainter(
                    progress: value,
                    color: color,
                    trackColor: track,
                  ),
                ),
              ),
              Text(
                letter,
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w800,
                  color: txt,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$current / ${target}g',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: label,
            letterSpacing: -0.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  static const _stroke = 4.5;

  _MiniRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - _stroke / 2 - 1;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress.clamp(0.0, 1.0) * 2 * math.pi,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) =>
      old.progress != progress || old.color != color;
}
