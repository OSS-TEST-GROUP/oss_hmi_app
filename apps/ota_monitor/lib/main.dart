import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/config/config_loader.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';
import 'package:ota_monitor/controller/ota_collector.dart';

import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:ota_monitor/view/log_overlay.dart';

late AppConfig appConfig;
late RosKeeper rosKeeper;

void main(List<String> args) {
  runWithLogCapture(() async {
    appConfig = await loadConfig(args);
    rosKeeper = RosKeeper(appConfig);

    // Register OtaCollector before starting RosKeeper so the watchdog
    // can pick up the Ros instance as soon as it becomes available.
    Get.put<OtaCollector>(
      OtaCollector(
        topicFactory: (ros, name, type) =>
            Topic(ros: ros, name: name, type: type),
        historySize: appConfig.historySize,
        initialApps: appConfig.initialApps,
      ),
      permanent: true,
    );

    await rosKeeper.start();

    runApp(OtaMonitorApp(truncateLength: appConfig.truncateLength));
  });
}

class OtaMonitorApp extends StatelessWidget {
  const OtaMonitorApp({super.key, this.truncateLength = 100});

  final int truncateLength;

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
      home: OtaMonitorHomePage(
        title: 'OTA Monitor',
        truncateLength: truncateLength,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OtaMonitorHomePage extends StatelessWidget {
  const OtaMonitorHomePage({
    super.key,
    required this.title,
    this.truncateLength = 100,
  });

  final String title;
  final int truncateLength;

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
            color: Colors.black.withValues(alpha: 0.2),
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
          Expanded(
              child: OtaViewPage(truncateLength: truncateLength)),
        ],
      ),
    );
  }
}
