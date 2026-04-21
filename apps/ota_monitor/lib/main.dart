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
import 'package:ota_monitor/controller/settings_controller.dart';

import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:ota_monitor/view/settings_page.dart';
import 'package:ota_monitor/view/log_overlay.dart';

late AppConfig appConfig;
String? startupConfigWarning;

/// F008: mutable holder so SettingsController can swap the live RosKeeper
/// without forcing every reader to re-resolve a global. Also lets widget
/// tests inject a mock keeper.
class RosKeeperHolder extends ChangeNotifier {
  RosKeeperHolder(this._current);

  RosKeeper _current;
  RosKeeper get current => _current;

  void replace(RosKeeper next) {
    _current = next;
    notifyListeners();
  }
}

late RosKeeperHolder rosKeeperHolder;

void main(List<String> args) {
  runWithLogCapture(() async {
    appConfig = await loadConfig(args);
    // F007: surface any config-parse failure so the UI can warn the user.
    startupConfigWarning = lastConfigLoadWarning;
    rosKeeperHolder = RosKeeperHolder(RosKeeper(appConfig));

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

    await rosKeeperHolder.current.start();

    runApp(OtaMonitorApp(
      truncateLength: appConfig.truncateLength,
      configWarning: startupConfigWarning,
      keeperHolder: rosKeeperHolder,
    ));
  });
}

class OtaMonitorApp extends StatelessWidget {
  const OtaMonitorApp({
    super.key,
    this.truncateLength = 100,
    this.configWarning,
    this.keeperHolder,
  });

  final int truncateLength;
  final String? configWarning;

  /// F008: when null, falls back to the global `rosKeeperHolder` set in
  /// main(). Tests that pump OtaMonitorApp directly without providing a
  /// holder rely on this fallback (see integration_test/).
  final RosKeeperHolder? keeperHolder;

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
        keeperHolder: keeperHolder ?? rosKeeperHolder,
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
    required this.keeperHolder,
  });

  final String title;
  final int truncateLength;
  final String? configWarning;
  final RosKeeperHolder keeperHolder;

  @override
  State<OtaMonitorHomePage> createState() => _OtaMonitorHomePageState();
}

class _OtaMonitorHomePageState extends State<OtaMonitorHomePage>
    with SingleTickerProviderStateMixin {
  static const int _failureThreshold = 3;

  late final TabController _tabController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _settingsController = SettingsController(
      initialConfig: appConfig,
      readKeeper: () => widget.keeperHolder.current,
      writeKeeper: widget.keeperHolder.replace,
    );

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            key: const Key('btn_quit'),
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
          AnimatedBuilder(
            animation: widget.keeperHolder,
            builder: (_, __) => ValueListenableBuilder<int>(
              valueListenable:
                  widget.keeperHolder.current.consecutiveFailures,
              builder: (_, failures, __) {
                if (failures < _failureThreshold) return const SizedBox();
                return Tooltip(
                  message: 'ROS 재연결 $failures회 실패',
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    key: Key('icon_ros_warning'),
                    color: Color(0xFFF59E0B),
                    size: 28,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Material(
      color: const Color(0xFF1E293B),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF60A5FA),
        unselectedLabelColor: const Color(0xFF9CA3AF),
        indicatorColor: const Color(0xFF3B82F6),
        tabs: const [
          Tab(key: Key('tab_apps'), text: 'Apps'),
          Tab(key: Key('tab_actor'), text: 'Actor'),
          Tab(key: Key('tab_client'), text: 'Client'),
          Tab(key: Key('tab_settings'), text: 'Settings'),
        ],
      ),
    );
  }

  Widget _placeholder(String label, String featureId) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction,
                  size: 56, color: Color(0xFF6B7280)),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming in $featureId',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const Key('btn_log_overlay'),
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
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                OtaViewPage(truncateLength: widget.truncateLength),
                _placeholder('Actor service raw calls', 'F009'),
                _placeholder('Client service interface', 'F021'),
                SettingsPage(
                  controller: _settingsController,
                  currentUrlProvider: () =>
                      widget.keeperHolder.current.cfg.rosUrl.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
