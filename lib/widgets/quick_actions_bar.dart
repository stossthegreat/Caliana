import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class QuickAction {
  final String id;
  final String emoji;
  final String label;
  final bool primary;
  const QuickAction(
    this.id,
    this.emoji,
    this.label, {
    this.primary = false,
  });
}

/// Horizontal scroller of preset chips. First chip is "Fix my day" —
/// blue gradient + pulsing — same SIZE as the others, just visually loud.
class QuickActionsBar extends StatelessWidget {
  final void Function(String id) onTap;

  const QuickActionsBar({super.key, required this.onTap});

  // "Save tonight" is sharper than "Fix my day" — it tells the user
  // exactly what tapping does (suggest dinner that lands you on
  // target). "Plan tomorrow" lives in the bar so the user has a
  // direct path into the Plan tab from any screen.
  static const actions = <QuickAction>[
    QuickAction('save_tonight', '⚡', 'Save tonight', primary: true),
    QuickAction('plan_tomorrow', '📅', 'Plan tomorrow'),
    QuickAction('log_meal', '🍝', 'Log meal'),
    QuickAction('high_protein', '🍗', 'High protein'),
    QuickAction('eat_clean', '🥗', 'Eat clean'),
    QuickAction('had_junk', '🍔', 'Had junk'),
    QuickAction('quick_lunch', '⏱', 'Quick lunch'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final a = actions[i];
          if (a.primary) {
            return _PulsingPrimaryChip(
              action: a,
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap(a.id);
              },
            );
          }
          return _Chip(
            action: a,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(a.id);
            },
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _Chip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 6, 13, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.surfaceBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(action.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingPrimaryChip extends StatefulWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _PulsingPrimaryChip({required this.action, required this.onTap});

  @override
  State<_PulsingPrimaryChip> createState() => _PulsingPrimaryChipState();
}

class _PulsingPrimaryChipState extends State<_PulsingPrimaryChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = 1.0 + t * 0.04;
        final glow = 0.35 + t * 0.30;
        final spread = 0.5 + t * 3.0;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 6, 13, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5A8AFF),
                    Color(0xFF2F6BFF),
                    Color(0xFF1F4FE0),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: glow),
                    blurRadius: 14,
                    spreadRadius: spread,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    widget.action.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
