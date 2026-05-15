import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/config/config_loader.dart';
import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/logging/app_log.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';
import 'package:ota_monitor/controller/client_service_controller.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/controller/settings_controller.dart';

import 'package:ota_monitor/view/ota_view_page.dart';
import 'package:ota_monitor/view/settings_page.dart';
import 'package:ota_monitor/view/log_overlay.dart';
import 'package:ota_monitor/theme/app_palette.dart';

// L009: Export view widget for launcher embedding
export 'view/ota_view_page.dart' show OtaViewPage;

late AppConfig appConfig;
String? startupConfigWarning;

/// Mutable holder so SettingsController can swap the live RosKeeper
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
    startupConfigWarning = lastConfigLoadWarning;
    paletteNotifier.value = Palette.fromName(appConfig.theme);
    rosKeeperHolder = RosKeeperHolder(RosKeeper(appConfig));

    // Register OtaCollector before starting RosKeeper so the watchdog
    // can pick up the Ros instance as soon as it becomes available.
    Get.put<OtaCollector>(
      OtaCollector(
        topicFactory: (ros, name, type) =>
            Topic(ros: ros, name: name, type: type),
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

  /// When null, falls back to the global `rosKeeperHolder` set in main().
  /// Tests that pump OtaMonitorApp directly without providing a holder
  /// rely on this fallback (see integration_test/).
  final RosKeeperHolder? keeperHolder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Palette>(
      valueListenable: paletteNotifier,
      builder: (_, p, __) => MaterialApp(
        title: 'OTA Monitor App',
        theme: p.toThemeData(),
        home: OtaMonitorHomePage(
          title: 'OTA Monitor',
          truncateLength: truncateLength,
          configWarning: configWarning,
          keeperHolder: keeperHolder ?? rosKeeperHolder,
        ),
        debugShowCheckedModeBanner: false,
      ),
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

class _OtaMonitorHomePageState extends State<OtaMonitorHomePage> {
  static const int _failureThreshold = 3;

  late final SettingsController _settingsController;

  // Shared notifier so the left app list → right Actor cards can pre-fill
  // app_name.
  final ValueNotifier<String?> _selectedApp = ValueNotifier(null);

  // Listen to Ros status so we can eagerly create _clientController when
  // the connection comes up.
  RosKeeper? _statusListenedKeeper;

  /// Client controller is created the moment Ros becomes available so
  /// the left-panel Client section can render registration / manager
  /// status / app status without waiting for user interaction.
  ClientServiceController? _clientController;

  @override
  void initState() {
    super.initState();

    _settingsController = SettingsController(
      initialConfig: appConfig,
      readKeeper: () => widget.keeperHolder.current,
      writeKeeper: widget.keeperHolder.replace,
    );

    _statusListenedKeeper = widget.keeperHolder.current;
    widget.keeperHolder.addListener(_onKeeperHolderChange);
    _statusListenedKeeper!.statusNotifier.addListener(_onRosStatusChange);
    // Try eagerly in case Ros is already up at startup.
    _ensureClientController();

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
    _selectedApp.dispose();
    widget.keeperHolder.removeListener(_onKeeperHolderChange);
    _statusListenedKeeper?.statusNotifier.removeListener(_onRosStatusChange);
    super.dispose();
  }

  void _onKeeperHolderChange() {
    final newKeeper = widget.keeperHolder.current;
    if (newKeeper != _statusListenedKeeper) {
      _statusListenedKeeper?.statusNotifier.removeListener(_onRosStatusChange);
      _statusListenedKeeper = newKeeper;
      newKeeper.statusNotifier.addListener(_onRosStatusChange);
    }
    if (mounted) setState(() {});
  }

  void _onRosStatusChange() {
    _ensureClientController();
    if (mounted) setState(() {});
  }

  /// Create _clientController as soon as Ros is registered in GetX.
  /// Called from initState (eager attempt) and from _onRosStatusChange
  /// (retry after connect).
  void _ensureClientController() {
    if (_clientController != null) return;
    if (!Get.isRegistered<Ros>()) return;
    _clientController = ClientServiceController(ros: Get.find<Ros>());
    _clientController!.setup();
    if (mounted) setState(() {});
  }

  void quitApp() {
    appLog('[OTA] Quit button pressed');
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      exit(0);
    }
  }

  Widget _buildHeader() {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.divider, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('btn_quit'),
            icon: Icon(Icons.arrow_back, size: 28, color: p.textPrimary),
            onPressed: quitApp,
            tooltip: '종료',
          ),
          const SizedBox(width: 16),
          Icon(Icons.system_update, size: 32, color: p.primary),
          const SizedBox(width: 12),
          Text(
            'OTA Monitor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: p.textPrimary,
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: widget.keeperHolder,
            builder: (_, __) {
              final keeper = widget.keeperHolder.current;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<Status>(
                    valueListenable: keeper.statusNotifier,
                    builder: (_, st, __) => _ConnIndicator(status: st),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: keeper.consecutiveFailures,
                    builder: (_, failures, __) {
                      if (failures < _failureThreshold) return const SizedBox();
                      return Tooltip(
                        message: 'ROS 재연결 $failures회 실패',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          key: const Key('icon_ros_warning'),
                          color: p.warning,
                          size: 28,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    key: const Key('btn_settings'),
                    icon: const Icon(Icons.settings, size: 20),
                    label: const Text('Settings'),
                    style: TextButton.styleFrom(
                      foregroundColor: p.textSecondary,
                    ),
                    onPressed: () => _showSettingsDialog(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dialogHeader(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
  }) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: p.textTertiary),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final p = palette;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(
                ctx,
                icon: Icons.settings,
                color: p.accentBlue,
                title: 'Settings',
              ),
              Divider(color: p.divider, height: 1),
              Flexible(
                child: SettingsPage(
                  controller: _settingsController,
                  currentUrlProvider: () =>
                      widget.keeperHolder.current.cfg.rosUrl.toString(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: OtaViewPage(
              truncateLength: widget.truncateLength,
              selectedApp: _selectedApp,
              clientController: _clientController,
            ),
          ),
        ],
      ),
    );
  }
}

/// Header connection indicator. Renders an `icon_conn_status` dot + a
/// `text_conn_status` label that integration_test (and the operator)
/// can read to know whether ROS is connected, connecting, or
/// disconnected.
class _ConnIndicator extends StatelessWidget {
  const _ConnIndicator({required this.status});

  final Status status;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final ({Color color, String label}) view = switch (status) {
      Status.connected     => (color: p.success, label: 'connected'),
      Status.connecting    => (color: p.warning, label: 'connecting'),
      Status.errored       => (color: p.error, label: 'disconnected'),
      Status.closed        => (color: p.error, label: 'disconnected'),
      Status.none          => (color: p.textTertiary, label: 'disconnected'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          key: const Key('icon_conn_status'),
          color: view.color,
          size: 12,
        ),
        const SizedBox(width: 6),
        Text(
          view.label,
          key: const Key('text_conn_status'),
          style: TextStyle(
            fontSize: 13,
            color: p.textSecondary,
          ),
        ),
      ],
    );
  }
}
