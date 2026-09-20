import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../state/bitnet_state.dart';
import '../widgets/app_top_header.dart';
import '../widgets/app_bottom_nav.dart';
import 'chat_screen.dart';
import 'models_screen.dart';
import 'monitoring_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final BitNetState state;

  const MainShell({super.key, required this.state});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<String> _tabNames = ['Chat', 'Models', 'Monitoring', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final currentTab = widget.state.currentTab;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(
            children: [
              // Top Persistent Header
              AppTopHeader(
                state: widget.state,
                sectionName: _tabNames[currentTab],
              ),
              // Body Screen Stack
              Expanded(
                child: IndexedStack(
                  index: currentTab,
                  children: [
                    ChatScreen(state: widget.state),
                    ModelsScreen(state: widget.state),
                    MonitoringScreen(state: widget.state),
                    SettingsScreen(state: widget.state),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: currentTab,
            onTabSelected: (index) => widget.state.setTab(index),
          ),
        );
      },
    );
  }
}
