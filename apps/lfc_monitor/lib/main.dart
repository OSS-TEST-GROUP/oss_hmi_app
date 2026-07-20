import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'config/app_config.dart';
import 'config/config_loader.dart';
import 'controller/lifecycle_collector.dart';
import 'data/lifecycle_data.dart';
import 'ros_keeper.dart';
import 'theme/lfc_palette.dart';
import 'view/lfc_view_page.dart';

// Export for hmi_launcher embedding (mirrors adsw_monitor / ota_monitor).
export 'view/lfc_view_page.dart' show LfcViewPage;
export 'config/app_config.dart' show AppConfig;
export 'theme/lfc_palette.dart' show LfcPalette, paletteNotifier, palette;

/// Launcher hook: apply a global service mode (0 = NORMAL, 1 = OTA) to the
/// live [LifecycleCollector]. When lfc_monitor is embedded its own Settings
/// gear is hidden, so the launcher's Settings screen drives the NORMAL/OTA
/// toggle through this entry point instead. Returns false when lfc isn't
/// active yet (its panel has never been opened, so no collector exists) —
/// the caller can surface a "open Lifecycle Monitor first" hint.
bool applyGlobalServiceMode(int modeValue) {
  if (!Get.isRegistered<LifecycleCollector>()) return false;
  Get.find<LifecycleCollector>()
      .setAllServicesMode(ServiceMode.fromInt(modeValue));
  return true;
}

late AppConfig appConfig;
late RosKeeperHolder rosKeeperHolder;

/// F014: mutable holder so SettingsController can swap the live RosKeeper
/// (after a URL change) without making every reader re-resolve a global.
/// Also lets widget tests inject a fake keeper.
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
  paletteNotifier.value = LfcPalette.fromName(appConfig.theme);

  rosKeeperHolder = RosKeeperHolder(RosKeeper(appConfig));
  await rosKeeperHolder.current.start();

  // Ensure GetX has the Ros instance even before the first Status.connected
  // event arrives — keeps the collector's watchdog from racing.
  if (!Get.isRegistered<Ros>()) {
    Get.put<Ros>(rosKeeperHolder.current.ros, permanent: true);
  }

  runApp(LfcMonitorApp(
    cfg: appConfig,
    keeperHolder: rosKeeperHolder,
  ));
}

class LfcMonitorApp extends StatelessWidget {
  const LfcMonitorApp({
    super.key,
    required this.cfg,
    this.keeperHolder,
  });

  final AppConfig cfg;

  /// When null, falls back to the global rosKeeperHolder set in main().
  /// Tests that pump LfcMonitorApp directly without providing a holder
  /// rely on this fallback.
  final RosKeeperHolder? keeperHolder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LfcPalette>(
      valueListenable: paletteNotifier,
      builder: (_, p, __) => MaterialApp(
        title: 'lfc_monitor',
        debugShowCheckedModeBanner: false,
        theme: p.toThemeData(),
        home: LfcViewPage(
          cfg: cfg,
          palette: p,
          keeperHolder: keeperHolder ?? rosKeeperHolder,
        ),
      ),
    );
  }
}
