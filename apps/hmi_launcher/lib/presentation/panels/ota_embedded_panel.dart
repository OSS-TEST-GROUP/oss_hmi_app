import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_monitor/config/app_config.dart' as ota_config;
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/main.dart' as ota
    show OtaMonitorHomePage, RosKeeperHolder, appConfig;
import 'package:ota_monitor/ros/ros_keeper.dart' as ota_ros;
import 'package:ota_monitor/theme/app_palette.dart' as ota_theme;

/// Embeds [OtaViewPage] while preserving OTA Monitor's own theme.
///
/// L009 fix: OTA Monitor's standalone `main()` is NOT run when embedded, so
/// the global `appConfig` / `rosKeeperHolder` it would set stay uninitialised
/// and OtaViewPage would fall back to a never-connected keeper. Mirror
/// lfc_embedded_panel: build a RosKeeperHolder here, set the global appConfig,
/// start the keeper, and inject the holder into OtaViewPage so the Client
/// section reflects the live rosbridge connection.
class OtaEmbeddedPanel extends StatefulWidget {
  const OtaEmbeddedPanel({super.key, this.rosUrl});

  /// rosbridge URL injected by the launcher (its own `_launcherConfig.rosUrl`,
  /// which itself resolves to the launcher config file value, or the launcher
  /// default). When null the panel falls back to OTA's own
  /// [AppConfig.defaults] (localhost) as a last resort.
  final Uri? rosUrl;

  @override
  State<OtaEmbeddedPanel> createState() => _OtaEmbeddedPanelState();
}

class _OtaEmbeddedPanelState extends State<OtaEmbeddedPanel> {
  late final ota_config.AppConfig _config = widget.rosUrl == null
      ? ota_config.AppConfig.defaults()
      : ota_config.AppConfig.defaults().copyWith(rosUrl: widget.rosUrl);
  late final ota.RosKeeperHolder _keeperHolder =
      ota.RosKeeperHolder(ota_ros.RosKeeper(_config));

  @override
  void initState() {
    super.initState();
    // OtaMonitorHomePage.initState reads the global `appConfig`; set it for
    // the embedded case (standalone main() never runs here).
    ota.appConfig = _config;
    // ota_view_page only USES OtaCollector when it's already registered (it
    // does not create one like lfc does), so register it here. The collector
    // resolves Ros lazily via Get.find<Ros>() — our keeper publishes it on
    // connect.
    if (!Get.isRegistered<OtaCollector>()) {
      Get.put<OtaCollector>(OtaCollector(), permanent: true);
    }
    // OtaViewPage does not auto-start the keeper (standalone main() does),
    // so kick off the rosbridge connection here.
    _keeperHolder.current.start();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ota_theme.Palette>(
      valueListenable: ota_theme.paletteNotifier,
      builder: (_, palette, __) => Theme(
        data: palette.toThemeData(),
        child: Material(
          color: palette.background,
          // Mount the full home page (header connection indicator + view) so
          // its status listener wires up the ClientServiceController on Ros
          // connect — OtaViewPage alone shows "Ros connecting…" forever.
          child: ota.OtaMonitorHomePage(
            title: 'OTA Monitor',
            truncateLength: 100,
            keeperHolder: _keeperHolder,
            embedded: true,
          ),
        ),
      ),
    );
  }
}
