import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'domain/launcher_config.dart';
import 'domain/plugin_registry.dart';
import 'presentation/shell/launcher_shell.dart';
import 'presentation/theme/launcher_tokens.dart';
import 'ros/launcher_ros_keeper.dart';

/// Semver string of this launcher build. Compared against manifest
/// `min_launcher` to decide plugin compatibility.
const String launcherVersion = '4.0.0';

/// Root of the `apps/` tree the registry scans at startup. Relative to the
/// launcher process's current working directory; adjust when the launcher
/// is packaged as an AGL bundle.
const String appsRoot = 'apps';

void main() {
  runApp(const HmiLauncherApp());
}

class HmiLauncherApp extends StatelessWidget {
  const HmiLauncherApp({
    super.key,
    this.initialRegistry,
    this.enableRos = true,
  });

  /// Allows tests to inject a fixture registry so the UI doesn't depend on
  /// a real filesystem.
  final PluginRegistry? initialRegistry;

  /// L009: Whether to initialize ROS. Tests should set false to avoid
  /// real network connections.
  final bool enableRos;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: LauncherTokens.bg1,
        colorScheme: ColorScheme.dark(
          primary: LauncherTokens.launcher,
          secondary: LauncherTokens.t2,
        ),
      ),
      home: LauncherHomePage(
        initialRegistry: initialRegistry,
        enableRos: enableRos,
      ),
    );
  }
}

class LauncherHomePage extends StatefulWidget {
  const LauncherHomePage({
    super.key,
    this.initialRegistry,
    this.enableRos = true,
  });

  final PluginRegistry? initialRegistry;
  final bool enableRos;

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  late final PluginRegistry _registry;
  LauncherRosKeeper? _rosKeeper;

  @override
  void initState() {
    super.initState();
    _registry = widget.initialRegistry ??
        PluginRegistryScanner(
          appsRoot: appsRoot,
          launcherVersion: launcherVersion,
        ).scan();
    // Initialize ROS immediately (synchronously) to ensure it's ready
    // before any embedded panels try to mount
    _initRosSync();
  }

  /// L009: Initialize unified ROS keeper for embedded plugins.
  ///
  /// Creates a single Ros instance registered in GetX. All plugin collectors
  /// (OtaCollector, AdswCollector, etc.) will find this via Get.find<Ros>().
  ///
  /// When enableRos=false (tests), a mock Ros is registered to prevent
  /// Get.find<Ros>() errors in collectors.
  void _initRosSync() {
    if (!widget.enableRos) {
      // Register mock Ros for tests to prevent Get.find<Ros>() errors
      _registerMockRos();
      return;
    }
    final config = LauncherConfig.defaults();
    _rosKeeper = LauncherRosKeeper(config);
    // Start ROS asynchronously but don't await (collectors will handle connection state)
    _rosKeeper!.start();
  }

  /// Registers a mock Ros instance for test environments.
  ///
  /// Plugin collectors call Get.find<Ros>() in their constructors.
  /// Without this, tests with enableRos=false would crash.
  void _registerMockRos() {
    if (Get.isRegistered<Ros>()) return; // Test may have injected one
    Get.put<Ros>(Ros(url: 'ws://mock:9090'));
  }

  @override
  void dispose() {
    _rosKeeper?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LauncherShell(
      registry: _registry,
    );
  }
}
