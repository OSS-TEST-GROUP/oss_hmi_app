import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:diag_monitor/config/config_loader.dart';
import 'package:diag_monitor/config/app_config.dart';
import 'package:roslibdart/roslibdart.dart';
import 'ros_keeper.dart';

import 'package:diag_monitor/view/mw_view_page.dart';
import 'package:diag_monitor/view/web_prompt_bootstrap.dart';
import 'package:diag_monitor/view/log_overlay.dart';
import 'package:diag_monitor/theme/diag_palette.dart';

// L009: Export view widgets for launcher embedding
export 'view/mw_view_page.dart' show MwViewPage;

late AppConfig appConfig;
late RosKeeper rosKeeper;

typedef RosKeeperFactory = RosKeeper Function(AppConfig cfg);

Future<void> startRosWithUri(
  Uri rosUrl, {
  RosKeeperFactory? keeperFactory,
}) async {
  // 웹에서 입력 받은 URL로 AppConfig 구성
  appConfig = AppConfig(
    rosUrl: rosUrl,
    statusTopic: '/app_status/diag_monitor',
  );

  // RosKeeper 생성 (테스트에서는 keeperFactory로 주입)
  final factory = keeperFactory ?? ((cfg) => RosKeeper(cfg));
  rosKeeper = factory(appConfig);

  // RosKeeper 시작
  await rosKeeper.start();

  // GetX 주입
  if (!Get.isRegistered<Ros>()) {
    Get.put<Ros>(rosKeeper.ros, permanent: true);
  } else {
    Get.replace<Ros>(rosKeeper.ros);
  }
}

void main(List<String> args) {
  //WidgetsFlutterBinding.ensureInitialized();

  runWithLogCapture(() async {
    if (kIsWeb) {
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: const WebPromptBootstrap(
            onConfigured: startRosWithUri,
            child: DiagMonitorApp(),
          ),
        ),
      );
    } else {
      appConfig = await loadConfig(args);
      rosKeeper = RosKeeper(appConfig);
      await rosKeeper.start();

      Get.put<Ros>(rosKeeper.ros, permanent: true);

      runApp(const DiagMonitorApp());
    }
  });
}

class DiagMonitorApp extends StatelessWidget {
  const DiagMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DiagPalette>(
      valueListenable: diagPaletteNotifier,
      builder: (_, palette, __) => DiagPaletteScope(
        palette: palette,
        child: MaterialApp(
          title: 'Diag Monitor App',
          theme: palette.toThemeData(),
          home: const DiagMonitorHomePage(title: 'Diag Monitor App Home'),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class DiagMonitorHomePage extends StatefulWidget {
  const DiagMonitorHomePage({
    super.key,
    required this.title,
    this.mwPageBuilder,
  });
  final String title;

  final Widget Function()? mwPageBuilder;

  @override
  State<DiagMonitorHomePage> createState() => _DiagMonitorHomePageState();
}

class _DiagMonitorHomePageState extends State<DiagMonitorHomePage> {
  @override
  void dispose() {
    rosKeeper.stop();
    super.dispose();
  }

  void quitApp() {
    if (Platform.isLinux) {
      exit(0);
    } else if (Platform.isAndroid) {
      SystemNavigator.pop();
    }
  }

  Widget _buildHeader() {
    final palette = DiagPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(bottom: BorderSide(color: palette.line, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.monitor_heart,
              color: palette.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            'Diagnostic Monitor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DiagPaletteScope.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Logs',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const LogBottomSheet(),
          );
        },
        child: const Icon(Icons.terminal),
      ),
      body: Container(
        color: palette.canvas,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: widget.mwPageBuilder?.call() ?? const MwViewPage(),
            ),
          ],
        ),
      ),
    );
  }
}
