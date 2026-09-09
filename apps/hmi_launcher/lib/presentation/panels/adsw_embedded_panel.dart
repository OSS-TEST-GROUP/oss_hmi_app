import 'package:adsw_monitor/main.dart' show AdswViewPage;
import 'package:adsw_monitor/theme/adsw_palette.dart';
import 'package:flutter/material.dart';

/// Embeds adsw_monitor's AD SW view while preserving adsw_monitor's original
/// standalone dark look.
///
/// The launcher shell is light, but adsw_monitor was designed against its
/// own slate dark theme. Wrapping the panel in a local [Theme] + [Material]
/// keeps colors consistent with the standalone app. Do NOT mount
/// `AdswMonitorHomePage` here — its dispose() calls `rosKeeper.stop()`,
/// which would tear down the launcher's shared ROS connection.
///
/// The middleware diagnostics view that used to live here as a second tab now
/// has its own app/panel — see `DiagEmbeddedPanel`.
class AdswEmbeddedPanel extends StatelessWidget {
  const AdswEmbeddedPanel({super.key});

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
            child: const AdswViewPage(),
          ),
        ),
      ),
    );
  }
}
