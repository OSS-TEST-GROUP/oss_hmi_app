import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'domain/launcher_config.dart';
import 'domain/plugin_registry.dart';
import 'presentation/keyboard/keyboard_host.dart';
import 'presentation/shell/launcher_app_area.dart';
import 'presentation/shell/launcher_bot_shell.dart';
import 'presentation/shell/launcher_shell.dart';
import 'presentation/theme/launcher_tokens.dart';
import 'ros/launcher_ros_keeper.dart';

/// Semver string of this launcher build. Compared against manifest
/// `min_launcher` to decide plugin compatibility.
const String launcherVersion = '4.0.0';

/// Resolve the plugin `apps/` root at startup.
///
/// Priority:
///   1. `HMI_APPS_ROOT` environment variable (absolute or relative path).
///   2. First candidate that contains at least one `<app>/manifest.json`.
///      Candidates cover common run contexts:
///        - `apps`           : CWD == repo root
///        - `..`             : CWD == apps/hmi_launcher (flutter run)
///        - `../..`, `../../apps` : CWD == build/linux/x64/.../bundle
///   3. Fallback: `apps` (yields empty registry, no crash).
String resolveAppsRoot() {
  final override = Platform.environment['HMI_APPS_ROOT'];
  if (override != null && override.isNotEmpty) return override;

  final candidates = <String>[
    'apps',
    '..',
    '../..',
    '../apps',
    '../../apps',
    '../../../apps',
    ..._aglFlutterAppsCandidates('hmi_launcher'),
  ];
  for (final c in candidates) {
    if (_containsPluginManifest(c)) return c;
  }
  return 'apps';
}

bool _containsPluginManifest(String appsRoot) {
  final dir = Directory(appsRoot);
  if (!dir.existsSync()) return false;
  return dir.listSync(followLinks: false).whereType<Directory>().any((sub) =>
      File('${sub.path}${Platform.pathSeparator}manifest.json').existsSync());
}

List<String> _aglFlutterAppsCandidates(String appName) {
  final appShareRoot = Directory('/usr/share/flutter/$appName');
  if (!appShareRoot.existsSync()) return const <String>[];

  final candidates = <String>[];
  for (final versionDir
      in appShareRoot.listSync(followLinks: false).whereType<Directory>()) {
    candidates.add('${versionDir.path}/apps');
    for (final mode in const ['release', 'profile', 'debug']) {
      candidates.add('${versionDir.path}/$mode/apps');
    }
  }
  return candidates;
}

void main() {
  runApp(const HmiLauncherApp());
}

class HmiLauncherApp extends StatelessWidget {
  const HmiLauncherApp({
    super.key,
    this.initialRegistry,
    this.enableRos = true,
    this.panelBuilder,
  });

  /// Allows tests to inject a fixture registry so the UI doesn't depend on
  /// a real filesystem.
  final PluginRegistry? initialRegistry;

  /// L009: Whether to initialize ROS. Tests should set false to avoid
  /// real network connections.
  final bool enableRos;

  /// Optional plugin-panel factory override. Forwarded to [LauncherShell]
  /// via [LauncherHomePage]; used by tests to skip plugin internals.
  final AppPanelBuilder? panelBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: LauncherTokens.fontBody,
        scaffoldBackgroundColor: LauncherTokens.bg0,
        colorScheme: const ColorScheme.light(
          primary: LauncherTokens.accent,
          onPrimary: LauncherTokens.bg0,
          surface: LauncherTokens.bg0,
          onSurface: LauncherTokens.t1,
        ),
        splashFactory: NoSplash.splashFactory,
      ),
      builder: (context, child) => KeyboardHost(child: child!),
      home: LauncherHomePage(
        initialRegistry: initialRegistry,
        enableRos: enableRos,
        panelBuilder: panelBuilder,
      ),
    );
  }
}

class LauncherHomePage extends StatefulWidget {
  const LauncherHomePage({
    super.key,
    this.initialRegistry,
    this.enableRos = true,
    this.panelBuilder,
  });

  final PluginRegistry? initialRegistry;
  final bool enableRos;
  final AppPanelBuilder? panelBuilder;

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  late final PluginRegistry _registry;
  late LauncherConfig _launcherConfig;
  String _rosStatus = 'Loading';
  LauncherRosKeeper? _rosKeeper;

  @override
  void initState() {
    super.initState();
    _registry = widget.initialRegistry ??
        PluginRegistryScanner(
          appsRoot: resolveAppsRoot(),
          launcherVersion: launcherVersion,
        ).scan();
    _launcherConfig = LauncherConfig.defaults();
    _loadConfigAndInitRos();
  }

  /// L009: Initialize unified ROS keeper for embedded plugins.
  ///
  /// Creates a single Ros instance registered in GetX. All plugin collectors
  /// (OtaCollector, AdswCollector, etc.) will find this via Get.find<Ros>().
  ///
  /// When enableRos=false (tests), a mock Ros is registered to prevent
  /// Get.find<Ros>() errors in collectors.
  Future<void> _loadConfigAndInitRos() async {
    final loadedConfig = await _LauncherConfigStore.load();
    if (!mounted) return;
    setState(() {
      _launcherConfig = loadedConfig;
      _rosStatus = widget.enableRos ? 'Configured' : 'Disabled';
    });
    _initRosSync();
  }

  void _initRosSync() {
    if (!widget.enableRos) {
      // Register mock Ros for tests to prevent Get.find<Ros>() errors
      _registerMockRos();
      return;
    }
    _rosKeeper = LauncherRosKeeper(_launcherConfig);
    // Start ROS asynchronously but don't await (collectors will handle connection state)
    _rosKeeper!.start();
  }

  Future<void> _applyRosBridge(Uri rosUrl) async {
    final nextConfig = LauncherConfig(
      rosUrl: rosUrl,
      statusTopic: _launcherConfig.statusTopic,
      rosReconnectIntervalSec: _launcherConfig.rosReconnectIntervalSec,
      heartbeatIntervalSec: _launcherConfig.heartbeatIntervalSec,
    );

    setState(() {
      _launcherConfig = nextConfig;
      _rosStatus = 'Reconnecting';
    });

    await _LauncherConfigStore.save(nextConfig);

    if (!widget.enableRos) {
      setState(() => _rosStatus = 'Disabled');
      return;
    }

    await _rosKeeper?.stop();
    _rosKeeper = LauncherRosKeeper(nextConfig);
    await _rosKeeper!.start();
    if (mounted) setState(() => _rosStatus = 'Configured');
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
    return LauncherBotShell(
      registry: _registry,
      panelBuilder: widget.panelBuilder,
      rosUrl: _launcherConfig.rosUrl,
      rosStatus: widget.enableRos ? _rosStatus : 'Disabled',
      onRosUrlChanged: _applyRosBridge,
    );
  }
}

class _LauncherConfigStore {
  static Future<LauncherConfig> load() async {
    final defaults = LauncherConfig.defaults();
    final file = await _firstExistingConfigFile();
    if (file == null) return defaults;

    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LauncherConfig.fromJson(json);
    } catch (error) {
      debugPrint('[LauncherConfig] failed to load ${file.path}: $error');
      return defaults;
    }
  }

  static Future<void> save(LauncherConfig config) async {
    final file = _writableConfigFile();
    final json = const JsonEncoder.withIndent('  ').convert({
      'rosbridge': {'url': config.rosUrl.toString()},
      'statusTopic': config.statusTopic,
      'rosReconnectIntervalSec': config.rosReconnectIntervalSec,
      'heartbeatIntervalSec': config.heartbeatIntervalSec,
    });

    try {
      await file.parent.create(recursive: true);
      await file.writeAsString('$json\n');
      debugPrint('[LauncherConfig] saved: ${file.path}');
    } catch (error) {
      debugPrint('[LauncherConfig] failed to save ${file.path}: $error');
    }
  }

  static Future<File?> _firstExistingConfigFile() async {
    for (final file in _candidateFiles()) {
      if (await file.exists()) return file;
    }
    return null;
  }

  static File _writableConfigFile() {
    final override = Platform.environment['HMI_LAUNCHER_CONFIG'];
    if (override != null && override.isNotEmpty) return File(override);

    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return File('$xdg/hmi_launcher/config.json');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return File('$home/.config/hmi_launcher/config.json');
    }

    return File('/var/lib/hmi_launcher/config.json');
  }

  static List<File> _candidateFiles() {
    final files = <File>[];

    final override = Platform.environment['HMI_LAUNCHER_CONFIG'];
    if (override != null && override.isNotEmpty) files.add(File(override));

    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      files.add(File('$xdg/hmi_launcher/config.json'));
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      files.add(File('$home/.config/hmi_launcher/config.json'));
    }

    files.add(File('/var/lib/hmi_launcher/config.json'));
    files.add(File('/etc/hmi_launcher/config.json'));
    return files;
  }
}
