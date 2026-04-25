import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Soft light backdrop. Solid off-white with two faint tinted radials
/// (cool blue, warm coral) drifting on a long loop. Barely perceptible —
/// just enough warmth so the background isn't dead-flat.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final aX = -0.4 + 0.5 * t;
        final aY = -0.7 + 0.3 * (1 - t);
        final bX = 0.6 - 0.5 * t;
        final bY = 0.4 + 0.2 * t;

        return Stack(
          children: [
            Container(color: AppColors.background),
            // Top-down soft tint — adds depth so the background doesn't
            // read as a flat sheet of beige under the cards.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                      AppColors.accent.withValues(alpha: 0.03),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(aX, aY),
                    radius: 1.4,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.primary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(bX, bY),
                    radius: 1.5,
                    colors: [
                      AppColors.accent.withValues(alpha: 0.13),
                      AppColors.accent.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
