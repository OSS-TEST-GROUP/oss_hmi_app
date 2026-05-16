import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'config/app_config.dart';
import 'config/config_loader.dart';
import 'ros_keeper.dart';
import 'theme/lfc_palette.dart';
import 'view/lfc_view_page.dart';

// Export for hmi_launcher embedding (mirrors adsw_monitor / ota_monitor).
export 'view/lfc_view_page.dart' show LfcViewPage;
export 'config/app_config.dart' show AppConfig;
export 'theme/lfc_palette.dart' show LfcPalette;

late AppConfig appConfig;
late RosKeeper rosKeeper;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  appConfig = await loadConfig(args);
  rosKeeper = RosKeeper(appConfig);
  await rosKeeper.start();

  // Ensure GetX has the Ros instance even before the first Status.connected
  // event arrives — keeps the collector's watchdog from racing.
  if (!Get.isRegistered<Ros>()) {
    Get.put<Ros>(rosKeeper.ros, permanent: true);
  }

  runApp(LfcMonitorApp(cfg: appConfig));
}

class LfcMonitorApp extends StatelessWidget {
  const LfcMonitorApp({super.key, required this.cfg});

  final AppConfig cfg;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lfc_monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: LfcPalette.defaults.background,
      ),
      home: LfcViewPage(cfg: cfg),
    );
  }
}
