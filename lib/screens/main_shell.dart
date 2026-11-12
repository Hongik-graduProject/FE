// lib/screens/main_shell.dart
// 로그인 후 첫 화면. 하단 탭 5개(홈·레이더·탐색·알림·MY)를 묶는다.
import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'radar_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      goTo: _goTo,
      currentIndex: _index,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            const HomeScreen(),
            // 레이더는 보고 있을 때만 만든다: 숨은 탭에서 SSE 연결과 60초 애니메이션이 계속 돌지 않게.
            _index == 1 ? const RadarScreen() : const SizedBox.shrink(),
            const SearchScreen(isTab: true),
            const NotificationsScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _goTo,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
              NavigationDestination(
                  icon: Icon(Icons.radio_button_checked_outlined), selectedIcon: Icon(Icons.radio_button_checked), label: '레이더'),
              NavigationDestination(
                  icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded), label: '탐색'),
              NavigationDestination(
                  icon: Icon(Icons.notifications_active_outlined),
                  selectedIcon: Icon(Icons.notifications_active_rounded),
                  label: '알림'),
              NavigationDestination(
                  icon: Icon(Icons.pie_chart_outline_rounded),
                  selectedIcon: Icon(Icons.pie_chart_rounded),
                  label: 'MY'),
            ],
          ),
        ),
      ),
    );
  }
}

/// 탭 안의 화면이 다른 탭으로 이동할 때 쓴다. 예: 홈 빈 상태의 "종목 찾아보기" → 탐색 탭.
class MainShellScope extends InheritedWidget {
  final void Function(int index) goTo;
  final int currentIndex;

  const MainShellScope({super.key, required this.goTo, required this.currentIndex, required super.child});

  static MainShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellScope>();

  @override
  bool updateShouldNotify(MainShellScope old) => old.currentIndex != currentIndex;
}
