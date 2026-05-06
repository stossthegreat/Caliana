import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'today_screen.dart';
import 'plan_screen.dart';

/// Globally-visible tab index. Any screen can switch tabs by writing to
/// MainTabs.activeTab (e.g. when the user taps a "Plan tomorrow" action
/// chip in the Today chat, that handler does:
///   MainTabs.activeTab.value = MainTabs.planTab;
class _TabIndex extends ValueNotifier<int> {
  _TabIndex() : super(0);
}

/// The two-tab home shell. Today on the left (log reality), Plan on the
/// right (control the future). Bottom bar matches the brand blue.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  static const int todayTab = 0;
  static const int planTab = 1;

  /// Singleton notifier so anywhere in the app can switch tabs without
  /// piping a callback through the widget tree.
  static final ValueNotifier<int> activeTab = _TabIndex();

  /// Convenience: go to the Plan tab.
  static void goToPlan() {
    activeTab.value = planTab;
  }

  /// Convenience: go to Today.
  static void goToToday() {
    activeTab.value = todayTab;
  }

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  static const _screens = [TodayScreen(), PlanScreen()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MainTabs.activeTab,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(index: index, children: _screens),
        bottomNavigationBar: _buildNav(index),
      ),
    );
  }

  Widget _buildNav(int currentIndex) {
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
                  current: currentIndex,
                  index: 0,
                  icon: Icons.chat_rounded,
                  label: 'Today',
                ),
              ),
              Expanded(
                child: _navItem(
                  current: currentIndex,
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
    required int current,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = current == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (current == index) return;
        HapticFeedback.lightImpact();
        MainTabs.activeTab.value = index;
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
