import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/config_loader.dart';
import 'view/rviz2_view_page.dart';

// Exports for hmi_launcher embedding.
export 'view/rviz2_view_page.dart' show Rviz2ViewPage;
export 'config/app_config.dart' show AppConfig;

late AppConfig appConfig;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  appConfig = await loadConfig(args);

  runApp(Rviz2MonitorApp(cfg: appConfig));
}

class Rviz2MonitorApp extends StatelessWidget {
  const Rviz2MonitorApp({super.key, required this.cfg});

  final AppConfig cfg;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rviz2_monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF97316), // orange — matches manifest
        useMaterial3: true,
      ),
      home: Rviz2ViewPage(cfg: cfg),
    );
  }
}
