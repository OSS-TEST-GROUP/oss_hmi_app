import 'package:flutter/material.dart';
import 'package:lfc_monitor/config/app_config.dart' as lfc_config;
import 'package:lfc_monitor/main.dart' as lfc;
import 'package:lfc_monitor/ros_keeper.dart' as lfc_ros;
import 'package:lfc_monitor/theme/lfc_palette.dart' as lfc_theme;

/// Embeds Lifecycle Monitor while preserving its own light/dark palette.
class LfcEmbeddedPanel extends StatefulWidget {
  const LfcEmbeddedPanel({super.key, this.rosUrl});

  /// rosbridge URL injected by the launcher (its own `_launcherConfig.rosUrl`,
  /// which itself resolves to the launcher config file value, or the launcher
  /// default). When null the panel falls back to lfc's own
  /// [AppConfig.defaults] (localhost) as a last resort.
  final Uri? rosUrl;

  @override
  State<LfcEmbeddedPanel> createState() => _LfcEmbeddedPanelState();
}

class _LfcEmbeddedPanelState extends State<LfcEmbeddedPanel> {
  late final lfc_config.AppConfig _config = widget.rosUrl == null
      ? lfc_config.AppConfig.defaults()
      : lfc_config.AppConfig.defaults().copyWith(rosUrl: widget.rosUrl);
  late final lfc.RosKeeperHolder _keeperHolder =
      lfc.RosKeeperHolder(lfc_ros.RosKeeper(_config));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<lfc_theme.LfcPalette>(
      valueListenable: lfc_theme.paletteNotifier,
      builder: (_, palette, __) => Theme(
        data: palette.toThemeData(),
        child: Material(
          color: palette.background,
          child: lfc.LfcViewPage(
            cfg: _config,
            palette: palette,
            keeperHolder: _keeperHolder,
            embedded: true,
          ),
        ),
      ),
    );
  }
}
