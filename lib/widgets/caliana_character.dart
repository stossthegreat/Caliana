import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Caliana herself — the brand character with gentle idle animation
/// and a soft drop shadow (no heavy glow on light theme).
class CalianaCharacter extends StatefulWidget {
  final double size;
  final bool floating;
  final VoidCallback? onTap;

  const CalianaCharacter({
    super.key,
    this.size = 160,
    this.floating = true,
    this.onTap,
  });

  @override
  State<CalianaCharacter> createState() => _CalianaCharacterState();
}

class _CalianaCharacterState extends State<CalianaCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        if (!widget.floating) return child!;
        final scale = 1.0 + (_ctrl.value * 0.018);
        final dy = (_ctrl.value * 3) - 1.5;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Image.asset(
          'assets/caliana.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (widget.onTap == null) return image;
    return GestureDetector(onTap: widget.onTap, child: image);
  }
}
