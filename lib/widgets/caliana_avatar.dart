import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small circular avatar of Caliana's face — used next to her chat bubbles.
/// Face-aligned crop (top portion of asset) with a soft blue ring + glow.
class CalianaAvatar extends StatelessWidget {
  final double size;
  final bool ring;

  const CalianaAvatar({super.key, this.size = 30, this.ring = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ring
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            )
          : null,
      padding: const EdgeInsets.all(1.2),
      child: ClipOval(
        child: Image.asset(
          'assets/caliana.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.55),
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
