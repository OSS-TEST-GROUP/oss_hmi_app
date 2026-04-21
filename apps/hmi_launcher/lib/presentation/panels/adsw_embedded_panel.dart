import 'package:adsw_monitor/main.dart' show AdswViewPage, MwViewPage;
import 'package:flutter/material.dart';

/// Embeds adsw_monitor's two views (AD SW + Middleware) behind a tab bar
/// while preserving adsw_monitor's original standalone dark look.
///
/// The launcher shell is light, but adsw_monitor was designed against its
/// own slate dark theme. Wrapping the panel in a local [Theme] + [Material]
/// keeps colors consistent with the standalone app. Do NOT mount
/// `AdswMonitorHomePage` here — its dispose() calls `rosKeeper.stop()`,
/// which would tear down the launcher's shared ROS connection.
class AdswEmbeddedPanel extends StatefulWidget {
  const AdswEmbeddedPanel({super.key});

  @override
  State<AdswEmbeddedPanel> createState() => _AdswEmbeddedPanelState();
}

class _AdswEmbeddedPanelState extends State<AdswEmbeddedPanel>
    with SingleTickerProviderStateMixin {
  // Mirrors AdswMonitorApp.theme in adsw_monitor/lib/main.dart.
  static const _bg = Color(0xFF0F172A);
  static const _accent = Color(0xFF3B82F6);
  static const _border = Color(0xFF1E293B);
  static const _textMuted = Color(0xFF94A3B8);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: Color(0xFF64748B),
        ),
      ),
      child: Material(
        color: _bg,
        child: Column(
          children: [
            _tabBar(),
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
        ),
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: _accent,
        indicatorWeight: 3,
        labelColor: Colors.white,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelColor: _textMuted,
        unselectedLabelStyle: const TextStyle(
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
