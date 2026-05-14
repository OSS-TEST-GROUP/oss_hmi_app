import 'package:flutter/material.dart';
import 'package:ota_monitor/main.dart' show OtaViewPage;
import 'package:ota_monitor/theme/app_palette.dart' as ota_theme;

/// Embeds [OtaViewPage] while preserving OTA Monitor's own theme.
class OtaEmbeddedPanel extends StatelessWidget {
  const OtaEmbeddedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ota_theme.Palette>(
      valueListenable: ota_theme.paletteNotifier,
      builder: (_, palette, __) => Theme(
        data: palette.toThemeData(),
        child: Material(
          color: palette.background,
          child: const OtaViewPage(truncateLength: 100),
        ),
      ),
    );
  }
}
