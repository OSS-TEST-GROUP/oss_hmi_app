import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'config/app_config.dart';
import 'config/config_loader.dart';
import 'ros_keeper.dart';
import 'view/rviz2_view_page.dart';

// Exports for hmi_launcher embedding (mirrors lfc_monitor / adsw_monitor pattern).
export 'view/rviz2_view_page.dart' show Rviz2ViewPage;
export 'config/app_config.dart' show AppConfig;

late AppConfig appConfig;
late RosKeeperHolder rosKeeperHolder;

/// Mutable holder so callers (Settings / tests) can swap the live RosKeeper
/// (after a URL change) without making every reader re-resolve a global.
/// Also lets widget tests inject a fake keeper.
/// Mirrors lfc_monitor's RosKeeperHolder exactly so the embedded launcher
/// can use the same embedding pattern.
class RosKeeperHolder extends ChangeNotifier {
  RosKeeperHolder(this._current);

  RosKeeper _current;
  RosKeeper get current => _current;

  void replace(RosKeeper next) {
    _current = next;
    notifyListeners();
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  appConfig = await loadConfig(args);

  rosKeeperHolder = RosKeeperHolder(RosKeeper(appConfig));
  await rosKeeperHolder.current.start();

  // Ensure GetX has the Ros instance before the controller's watchdog fires
  // on the first 500ms tick — prevents a race in the Rviz2Controller.
  if (!Get.isRegistered<Ros>()) {
    Get.put<Ros>(rosKeeperHolder.current.ros, permanent: true);
  }

  runApp(Rviz2MonitorApp(
    cfg: appConfig,
    keeperHolder: rosKeeperHolder,
  ));
}

class Rviz2MonitorApp extends StatelessWidget {
  const Rviz2MonitorApp({
    super.key,
    required this.cfg,
    this.keeperHolder,
  });

  final AppConfig cfg;

  /// When null, falls back to the global [rosKeeperHolder] set in [main].
  /// Tests that pump Rviz2MonitorApp directly without providing a holder
  /// rely on this fallback.
  final RosKeeperHolder? keeperHolder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rviz2_monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF97316), // orange — matches manifest color
        useMaterial3: true,
      ),
      home: Rviz2ViewPage(
        cfg: cfg,
        keeperHolder: keeperHolder ?? rosKeeperHolder,
      ),
    );
  }
}
