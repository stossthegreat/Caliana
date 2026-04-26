import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'today_screen.dart';
import 'plan_screen.dart';

/// The two-tab home shell. Today on the left (log reality), Plan on the
/// right (control the future). Bottom bar matches the brand blue.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  static const _screens = [TodayScreen(), PlanScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: _navItem(
                  index: 0,
                  icon: Icons.chat_rounded,
                  label: 'Today',
                ),
              ),
              Expanded(
                child: _navItem(
                  index: 1,
                  icon: Icons.calendar_month_rounded,
                  label: 'Plan',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _index == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_index == index) return;
        HapticFeedback.lightImpact();
        setState(() => _index = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color:
                    selected ? AppColors.primary : AppColors.textHint,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
