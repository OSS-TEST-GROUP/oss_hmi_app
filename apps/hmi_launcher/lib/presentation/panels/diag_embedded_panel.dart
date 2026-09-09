import 'package:diag_monitor/main.dart' show MwViewPage;
import 'package:diag_monitor/theme/diag_palette.dart';
import 'package:flutter/material.dart';

/// Embeds diag_monitor's diagnostic view while preserving diag_monitor's
/// original standalone dark look.
///
/// The launcher shell is light, but diag_monitor was designed against its
/// own slate dark theme. Wrapping the panel in a local [Theme] + [Material]
/// keeps colors consistent with the standalone app. Do NOT mount
/// `DiagMonitorHomePage` here — its dispose() calls `rosKeeper.stop()`,
/// which would tear down the launcher's shared ROS connection.
///
/// Split out of [AdswEmbeddedPanel], which used to carry this view as its
/// second ("Diagnostic Info") tab.
class DiagEmbeddedPanel extends StatelessWidget {
  const DiagEmbeddedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DiagPalette>(
      valueListenable: diagPaletteNotifier,
      builder: (_, palette, __) => DiagPaletteScope(
        palette: palette,
        child: Theme(
          data: palette.toThemeData(),
          child: Material(
            color: palette.canvas,
            child: const MwViewPage(),
          ),
        ),
      ),
    );
  }
}
