import 'package:flutter/material.dart';
import 'package:ota_monitor/main.dart' show OtaViewPage;

/// Embeds [OtaViewPage] while preserving its original standalone look.
///
/// The launcher shell runs a light Material 3 theme, but `ota_monitor` was
/// designed against its own dark theme (slate background, blue primary).
/// Wrapping the view in a local [Theme] + [Material] restores the colors
/// OtaViewPage expects without duplicating its logic here. OtaViewPage
/// registers its own OtaCollector via GetX and reuses the shared [Ros]
/// instance published by LauncherRosKeeper.
class OtaEmbeddedPanel extends StatelessWidget {
  const OtaEmbeddedPanel({super.key});

  // Mirrors OtaMonitorApp.theme in ota_monitor/lib/main.dart.
  static const _bg = Color(0xFF0F172A);
  static ThemeData _theme() => ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF64748B),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(),
      child: const Material(
        color: _bg,
        child: OtaViewPage(truncateLength: 100),
      ),
    );
  }
}
