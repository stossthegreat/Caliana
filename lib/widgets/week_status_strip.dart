import 'package:flutter/material.dart';
import '../services/day_log_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';

/// 7-day status strip — Mon→Sun bars showing kcal vs target each day.
/// Past days coloured by under/on/over, today highlighted, future days
/// greyed. Below: a one-line headline that says where the week stands
/// (under target, on track, over by X). The "you always know where
/// you are" anchor of the Plan tab.
class WeekStatusStrip extends StatelessWidget {
  const WeekStatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = UserProfileService.instance.profile;
    final goal = profile.dailyCalorieGoal;
    final now = DateTime.now();

    // Pull last 6 days + today, oldest -> newest. weekday Mon=1..Sun=7.
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );

    final weeklyConsumed = DayLogService.instance.weeklyCalories;
    final weekTarget = goal * 7;
    final delta = weeklyConsumed - weekTarget;

    final (headline, sub, accent) = _statusCopy(delta, weeklyConsumed, weekTarget);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'THIS WEEK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in days) _DayBar(day: day, goal: goal, isToday: _sameDay(day, now)),
            ],
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  (String headline, String sub, Color accent) _statusCopy(
      int delta, int consumed, int weekTarget) {
    if (delta <= -1500) {
      return (
        'Under target this week',
        "${(-delta)} kcal under across 7 days. Don't undereat — listen to hunger.",
        AppColors.primary,
      );
    }
    if (delta <= 0) {
      return (
        'Tracking sound',
        "${(-delta).abs()} under, ${consumed.clamp(0, 99999)} kcal logged of $weekTarget target. Keep doing what you're doing.",
        const Color(0xFF22C55E),
      );
    }
    if (delta < 600) {
      return (
        'Tight, but absorbable',
        '$delta kcal over. Two lighter teas this week and you\'re square.',
        AppColors.primary,
      );
    }
    if (delta < 1500) {
      final perDay = (delta / 3).round();
      return (
        '$delta over, easy fix',
        'Trim ~$perDay kcal across the next 3 days. No crash, just steady.',
        AppColors.accent,
      );
    }
    return (
      '$delta over — proper rebuild',
      'Three to four days, protein-led, normal calories. We absorb it slowly.',
      AppColors.accent,
    );
  }
}

class _DayBar extends StatelessWidget {
  final DateTime day;
  final int goal;
  final bool isToday;

  const _DayBar({required this.day, required this.goal, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final log = DayLogService.instance.forDay(day);
    final consumed = log.totalCalories;
    final pct = goal == 0 ? 0.0 : consumed / goal;
    final isFuture = day.isAfter(DateTime.now());
    final hasData = consumed > 0;

    final fillHeight = pct.clamp(0.0, 1.4);
    final color = !hasData
        ? AppColors.surfaceBorder
        : pct < 0.85
            ? const Color(0xFF22C55E)
            : pct < 1.05
                ? AppColors.primary
                : AppColors.accent;

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final letter = labels[(day.weekday - 1) % 7];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF2F8),
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 1.4)
                : null,
          ),
          alignment: Alignment.bottomCenter,
          child: hasData
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 50 * fillHeight.clamp(0.06, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                )
              : isFuture
                  ? null
                  : SizedBox(
                      height: 6,
                      child: Center(
                        child: Container(
                          width: 12,
                          height: 2,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 5),
        Text(
          letter,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
            color: isToday ? AppColors.primary : AppColors.textHint,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
