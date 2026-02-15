import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:ota_monitor/config/config_loader.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:roslibdart/roslibdart.dart';
import 'ros_keeper.dart';

import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:ota_monitor/view/web_prompt_bootstrap.dart';
import 'package:ota_monitor/view/log_overlay.dart';

late AppConfig appConfig;
late RosKeeper rosKeeper;

typedef RosKeeperFactory = RosKeeper Function(AppConfig cfg);

Future<void> startRosWithUri(
  Uri rosUrl, {
  RosKeeperFactory? keeperFactory,
}) async {
  // 웹에서 입력 받은 URL로 AppConfig 구성
  appConfig = AppConfig(rosUrl: rosUrl, statusTopic: '/app_status/ota_monitor');

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
  runWithLogCapture(() async {
    if (kIsWeb) {
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: WebPromptBootstrap(
          onConfigured: startRosWithUri,
          child: const OtaMonitorApp(),
        ),
      ));
    } else {
      appConfig = await loadConfig(args);
      rosKeeper = RosKeeper(appConfig);
      await rosKeeper.start();

      Get.put<Ros>(rosKeeper.ros, permanent: true);

      runApp(const OtaMonitorApp());
    }
  });
}

class OtaMonitorApp extends StatelessWidget {
  const OtaMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTA Monitor App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF64748B),
        ),
      ),
      home: const OtaMonitorHomePage(title: 'OTA Monitor'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OtaMonitorHomePage extends StatelessWidget {
  const OtaMonitorHomePage({
    super.key,
    required this.title,
  });

  final String title;

  void quitApp() {
    debugPrint('[OTA] Quit button pressed');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      exit(0);
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: quitApp,
            tooltip: '종료',
          ),
          const SizedBox(width: 16),
          const Icon(Icons.system_update, size: 32, color: Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          const Text(
            'OTA Monitor',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1E293B),
            builder: (_) => const LogBottomSheet(),
          );
        },
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.terminal),
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Expanded(child: OtaViewPage()),
        ],
      ),
    );
  }
}
