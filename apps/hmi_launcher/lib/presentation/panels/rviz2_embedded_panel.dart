import 'package:flutter/material.dart';
import 'package:rviz2_monitor/main.dart' as rviz2;

/// Embeds the RViz2 Monitor inside hmi_launcher.
///
/// Unlike the other monitor panels (lfc/adsw/ota), rviz2_monitor does NOT use
/// rosbridge / lifecycle_mgr. It controls the local rviz2 docker container
/// directly (docker CLI via the mounted docker.sock) and switches the screen
/// via the AGL shell gRPC service (:14005) — so it takes no rosUrl. It uses
/// rviz2_monitor's own AppConfig.defaults() (container name / image / agl
/// output / docker run args).
class Rviz2EmbeddedPanel extends StatelessWidget {
  const Rviz2EmbeddedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: rviz2.Rviz2ViewPage(
        cfg: rviz2.AppConfig.defaults(),
        embedded: true,
      ),
    );
  }
}
