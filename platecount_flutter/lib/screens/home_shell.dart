import 'package:flutter/material.dart';
import '../api.dart';
import 'serve_screen.dart';
import 'inventory_screen.dart';
import 'change_screen.dart';
import 'dashboard_screen.dart';
import 'reports_screen.dart';
import 'team_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = <(IconData, String, Widget)>[
      (Icons.receipt_long, 'Serve', const ServeScreen()),
      if (api.isChef) (Icons.inventory_2_outlined, 'Stock', const InventoryScreen()),
      (Icons.payments_outlined, 'Change', const ChangeScreen()),
      if (api.isChef) (Icons.space_dashboard_outlined, 'Today', const DashboardScreen()),
      if (api.isChef) (Icons.bar_chart, 'Reports', const ReportsScreen()),
      if (api.isChef) (Icons.group_outlined, 'Team', const TeamScreen()),
    ];
    if (index >= tabs.length) index = 0;
    return Scaffold(
      body: SafeArea(child: tabs[index].$3),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$1), label: t.$2)],
      ),
    );
  }
}

/// Shared top header with user name + sign out.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const PageHeader(this.title, {super.key});
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(child: Text('${api.user?['display_name'] ?? ''} · ${api.user?['role']}')),
          ),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: api.signOut),
        ],
      );
}
