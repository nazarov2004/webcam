import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../features/camera/presentation/camera_studio_screen.dart';
import '../../features/connection/presentation/connection_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/settings/presentation/general_settings_screen.dart';

/// Root scaffold with a bottom navigation bar hosting the four primary tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const DashboardScreen(),
          CameraStudioScreen(embedded: true, isActive: _index == 1),
          const ConnectionScreen(),
          const GeneralSettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.primary.withValues(alpha: 0.18),
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Camera',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Studio',
              ),
              NavigationDestination(
                icon: Icon(Icons.wifi_tethering_outlined),
                selectedIcon: Icon(Icons.wifi_tethering_rounded),
                label: 'Connection',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}