import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/day_log_service.dart';
import '../services/user_profile_service.dart';

/// Horizontal date strip on the BLUE header.
/// Letter + day + adherence dot. Selected day is a white pill with blue text.
class DateStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const DateStrip({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - (6 - i)),
    );

    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days
            .map((d) => _DayDot(
                  date: d,
                  isToday: _sameDay(d, today),
                  isSelected: _sameDay(d, selected),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(d);
                  },
                ))
            .toList(),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayDot extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayDot({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final letter = _letter(date.weekday);
    final dayLog = DayLogService.instance.forDay(date);
    final goal = UserProfileService.instance.profile.dailyCalorieGoal;
    final pct = goal == 0 ? 0.0 : dayLog.totalCalories / goal;

    Color dotColor;
    if (!dayLog.hasEntries) {
      dotColor = Colors.transparent;
    } else if (pct < 0.85 && pct > 0.5) {
      dotColor = AppColors.success;
    } else if (pct >= 0.85 && pct <= 1.10) {
      dotColor = AppColors.warning;
    } else if (pct > 1.10) {
      dotColor = AppColors.accent;
    } else {
      dotColor = Colors.white.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 38,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? AppColors.primary : Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor == Colors.transparent
                    ? Colors.transparent
                    : isSelected
                        ? AppColors.primary
                        : dotColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _letter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[(weekday - 1).clamp(0, 6)];
  }
}
