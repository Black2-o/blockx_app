import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/page_header.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'progress_screen.dart';

/// The main app shell: three bottom-nav tabs (Home · Progress · Profile) in an
/// [IndexedStack] so each keeps its state. Blocking apps / reels / sites is done
/// from the Home dashboard's cards, each opening its own full page.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    NavTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    NavTab(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        label: 'Progress'),
    NavTab(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    const tabs = [
      // Home renders its own logo header.
      HomeDashboard(),
      _TabWithHeader(title: 'Progress', child: ProgressScreen(embedded: true)),
      _TabWithHeader(title: 'Profile', child: AccountScreen(embedded: true)),
    ];

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: AppBottomNav(
        tabs: _tabs,
        currentIndex: _index,
        onSelected: _select,
      ),
    );
  }
}

/// Wraps an embedded tab body with a non-back [PageHeader].
class _TabWithHeader extends StatelessWidget {
  const _TabWithHeader({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(title: title, showBack: false),
        Expanded(child: child),
      ],
    );
  }
}
