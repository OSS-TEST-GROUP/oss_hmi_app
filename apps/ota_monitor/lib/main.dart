import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/config/config_loader.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/logging/app_log.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';
import 'package:ota_monitor/controller/ota_collector.dart';

import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:ota_monitor/view/log_overlay.dart';

// L009: Export view widget for launcher embedding
export 'view/ota_view_page.dart' show OtaViewPage;

late AppConfig appConfig;
late RosKeeper rosKeeper;
String? startupConfigWarning;

void main(List<String> args) {
  runWithLogCapture(() async {
    appConfig = await loadConfig(args);
    // F007: surface any config-parse failure so the UI can warn the user.
    startupConfigWarning = lastConfigLoadWarning;
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

    runApp(OtaMonitorApp(
      truncateLength: appConfig.truncateLength,
      configWarning: startupConfigWarning,
      keeper: rosKeeper,
    ));
  });
}

class OtaMonitorApp extends StatelessWidget {
  const OtaMonitorApp({
    super.key,
    this.truncateLength = 100,
    this.configWarning,
    this.keeper,
  });

  final int truncateLength;
  final String? configWarning;
  final RosKeeper? keeper;

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
        configWarning: configWarning,
        keeper: keeper,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class OtaMonitorHomePage extends StatefulWidget {
  const OtaMonitorHomePage({
    super.key,
    required this.title,
    this.truncateLength = 100,
    this.configWarning,
    this.keeper,
  });

  final String title;
  final int truncateLength;
  final String? configWarning;
  final RosKeeper? keeper;

  @override
  State<OtaMonitorHomePage> createState() => _OtaMonitorHomePageState();
}

class _OtaMonitorHomePageState extends State<OtaMonitorHomePage> {
  static const int _failureThreshold = 3;

  @override
  void initState() {
    super.initState();
    // F007: show a one-shot dialog if config.json failed to parse at startup.
    if (widget.configWarning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('설정 파일 경고'),
            content: Text(widget.configWarning!),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      });
    }
  }

  void quitApp() {
    appLog('[OTA] Quit button pressed');
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
          const Spacer(),
          if (widget.keeper != null)
            ValueListenableBuilder<int>(
              valueListenable: widget.keeper!.consecutiveFailures,
              builder: (_, failures, __) {
                if (failures < _failureThreshold) return const SizedBox();
                return Tooltip(
                  message: 'ROS 재연결 $failures회 실패',
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 28,
                  ),
                );
              },
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
              child: OtaViewPage(truncateLength: widget.truncateLength)),
        ],
      ),
    );
  }
}
