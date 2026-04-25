import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Compact inline macro summary — "Protein → LOW · Carbs → HIGH · Fat → OK".
/// Replaces the big macro cards. Sits below the quick-actions row.
class InlineMacros extends StatelessWidget {
  final int protein, carbs, fat;
  final int proteinTarget, carbsTarget, fatTarget;

  const InlineMacros({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('Protein', protein, proteinTarget, AppColors.macroProtein),
          _divider(),
          _stat('Carbs', carbs, carbsTarget, AppColors.macroCarbs),
          _divider(),
          _stat('Fat', fat, fatTarget, AppColors.macroFat),
        ],
      ),
    );
  }

  Widget _stat(String label, int current, int target, Color color) {
    final state = _classify(current, target);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          state,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 12,
      color: AppColors.surfaceBorder,
    );
  }

  String _classify(int current, int target) {
    if (target == 0) return 'OK';
    final pct = current / target;
    if (pct < 0.5) return 'LOW';
    if (pct > 1.0) return 'HIGH';
    return 'OK';
  }
}
