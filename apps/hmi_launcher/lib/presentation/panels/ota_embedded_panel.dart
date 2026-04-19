import 'package:flutter/material.dart';
import 'package:ota_monitor/main.dart' show OtaViewPage;

/// L009: Panel that embeds the ota_monitor view widget.
///
/// Mounts OtaViewPage which handles its own OtaCollector registration via GetX.
class OtaEmbeddedPanel extends StatelessWidget {
  const OtaEmbeddedPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // OtaViewPage handles its own OtaCollector registration via GetX.
    // The launcher's LauncherRosKeeper has already registered the shared
    // Ros instance that OtaCollector will find via Get.find<Ros>().
    return const OtaViewPage(truncateLength: 100);
  }
}
