import 'package:flutter/material.dart';
import 'package:adsw_monitor/main.dart' show AdswViewPage, MwViewPage;

import '../theme/app_accent_scope.dart';
import '../theme/launcher_tokens.dart';

/// L009: Panel that embeds the adsw_monitor view widgets with tab navigation.
///
/// Wraps AdswViewPage and MwViewPage in a TabBarView with launcher styling.
///
/// WARNING: Do NOT use AdswMonitorHomePage here. Its dispose() calls
/// rosKeeper.stop() which would kill the shared ROS connection.
/// Use AdswViewPage + MwViewPage directly.
class AdswEmbeddedPanel extends StatefulWidget {
  const AdswEmbeddedPanel({super.key});

  @override
  State<AdswEmbeddedPanel> createState() => _AdswEmbeddedPanelState();
}

class _AdswEmbeddedPanelState extends State<AdswEmbeddedPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    // DO NOT call rosKeeper.stop() - launcher owns lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);
    return Column(
      children: [
        _buildTabBar(accent),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              AdswViewPage(),
              MwViewPage(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(Color accent) {
    // Simplified TabBar styled with launcher tokens
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(
          bottom: BorderSide(
            color: LauncherTokens.b1,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: accent,
        indicatorWeight: 3,
        labelColor: LauncherTokens.t1,
        labelStyle: const TextStyle(
          fontFamily: LauncherTokens.fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelColor: LauncherTokens.t3,
        unselectedLabelStyle: const TextStyle(
          fontFamily: LauncherTokens.fontBody,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'AD SW Info'),
          Tab(text: 'Diagnostic Info'),
        ],
      ),
    );
  }
}
