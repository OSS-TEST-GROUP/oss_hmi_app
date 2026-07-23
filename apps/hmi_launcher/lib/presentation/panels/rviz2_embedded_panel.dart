import 'package:flutter/material.dart';
import 'package:rviz2_monitor/config/app_config.dart' as rviz2_config;
import 'package:rviz2_monitor/main.dart' as rviz2;
import 'package:rviz2_monitor/ros_keeper.dart' as rviz2_ros;

/// Embeds the RViz2 Monitor inside hmi_launcher.
///
/// Mirrors LfcEmbeddedPanel: creates its own AppConfig + RosKeeperHolder so
/// the rviz2 monitor panel is isolated from other embedded panels while
/// sharing the same rosbridge URL injected by the launcher.
class Rviz2EmbeddedPanel extends StatefulWidget {
  const Rviz2EmbeddedPanel({super.key, this.rosUrl});

  /// rosbridge URL injected by the launcher (its own `_launcherConfig.rosUrl`,
  /// which itself resolves to the launcher config file value, or the launcher
  /// default). When null the panel falls back to rviz2_monitor's own
  /// [AppConfig.defaults] (localhost) as a last resort.
  final Uri? rosUrl;

  @override
  State<Rviz2EmbeddedPanel> createState() => _Rviz2EmbeddedPanelState();
}

class _Rviz2EmbeddedPanelState extends State<Rviz2EmbeddedPanel> {
  late final rviz2_config.AppConfig _config = widget.rosUrl == null
      ? rviz2_config.AppConfig.defaults()
      : rviz2_config.AppConfig.defaults().copyWith(rosUrl: widget.rosUrl);
  late final rviz2.RosKeeperHolder _keeperHolder =
      rviz2.RosKeeperHolder(rviz2_ros.RosKeeper(_config));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: rviz2.Rviz2ViewPage(
        cfg: _config,
        keeperHolder: _keeperHolder,
        embedded: true,
      ),
    );
  }
}
