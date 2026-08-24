import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/config_loader.dart';
import 'view/rviz2_view_page.dart';

// Exports for hmi_launcher embedding.
export 'view/rviz2_view_page.dart' show Rviz2ViewPage;
export 'config/app_config.dart' show AppConfig;
// 런처 셸이 앱 전환 시 rviz2 서페이스를 내리기 위해 필요하다(hideRviz2).
export 'controller/rviz2_controller.dart' show Rviz2Controller;
// 임베디드(hmi_launcher)에서도 단독 실행과 **같은 설정 해석**을 쓰도록 로더를 공개한다.
// (탐색 순서: --config → RVIZ2_MONITOR_CONFIG → ./config/config.json →
//  ~/.config/rviz2_panel/config.json → /etc/rviz2_panel/config.json → defaults)
export 'config/config_loader.dart' show loadConfig;

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
      title: 'rviz2_panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF97316), // orange — matches manifest
        useMaterial3: true,
      ),
      home: Rviz2ViewPage(cfg: cfg),
    );
  }
}
