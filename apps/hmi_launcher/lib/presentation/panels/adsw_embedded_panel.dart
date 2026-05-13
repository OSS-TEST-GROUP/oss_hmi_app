import 'package:adsw_monitor/main.dart' show AdswViewPage, MwViewPage;
import 'package:adsw_monitor/theme/adsw_palette.dart';
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
    return ValueListenableBuilder<AdswPalette>(
      valueListenable: adswPaletteNotifier,
      builder: (_, palette, __) => AdswPaletteScope(
        palette: palette,
        child: Theme(
          data: palette.toThemeData(),
          child: Material(
            color: palette.canvas,
            child: Column(
              children: [
                _tabBar(palette),
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
        ),
      ),
    );
  }

  Widget _tabBar(AdswPalette palette) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(bottom: BorderSide(color: palette.line, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: palette.primary,
        indicatorWeight: 3,
        labelColor: palette.text,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelColor: palette.muted,
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
