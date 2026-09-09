import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/theme/adsw_palette.dart' as adsw_theme;
import 'package:diag_monitor/theme/diag_palette.dart' as diag_theme;
import 'package:lfc_monitor/main.dart' as lfc;
import 'package:lfc_monitor/theme/lfc_palette.dart' as lfc_theme;
import 'package:ota_monitor/theme/app_palette.dart' as ota_theme;
import 'package:roslibdart/roslibdart.dart';

import 'domain/app_visibility_store.dart';
import 'domain/domain_store.dart';
import 'domain/mmf_restarter.dart';
import 'domain/timezone_store.dart';
import 'domain/launcher_config.dart';
import 'domain/plugin_registry.dart';
import 'launcher_bot/services/launcher_bot_ai_service.dart';
import 'presentation/keyboard/keyboard_host.dart';
import 'presentation/shell/launcher_app_area.dart';
import 'presentation/shell/launcher_bot_shell.dart';
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
    this.aiService,
    this.visibilityStore,
    this.botAvailabilityProbe,
    this.timezoneStore,
    this.domainStore,
    this.onDomainRemotePublish,
  });

  /// Allows tests to inject a fixture registry so the UI doesn't depend on
  /// a real filesystem.
  final PluginRegistry? initialRegistry;

  /// L009: Whether to initialize ROS. Tests should set false to avoid
  /// real network connections.
  final bool enableRos;

  /// Optional plugin-panel factory override. Forwarded to [LauncherBotShell]
  /// via [LauncherHomePage]; used by tests to skip plugin internals.
  final AppPanelBuilder? panelBuilder;

  /// Optional AI service override. When null [LauncherBotShell] builds its
  /// own [AgentSubmitAiService]. Tests inject [FallbackLauncherBotAiService]
  /// to avoid real gRPC connections and long timeouts.
  final LauncherBotAiService? aiService;

  /// F017: Optional visibility store override for tests.
  /// When null, [LauncherHomePage] creates a file-backed store.
  final AppVisibilityStore? visibilityStore;

  /// Optional launcher-bot availability probe override (tests). Forwarded to
  /// [LauncherBotShell]; when null the shell uses the real daemon probe.
  final BotAvailabilityProbe? botAvailabilityProbe;

  /// Optional timezone store override (tests). When null the page creates a
  /// file-backed store defaulting to Korea (KST).
  final TimezoneStore? timezoneStore;

  /// 통신 두 평면(DDS/ROS2) 도메인 설정 저장소. 테스트는 in-memory 를 주입한다.
  final DomainStore? domainStore;

  /// 원격 호스트(차량 컴퓨트)의 domain.env 갱신 요청. null 이면 rosbridge keeper 를
  /// 쓴다. 테스트는 가짜를 주입해 "로컬 저장값과 같은 값이 나가는지" 를 본다.
  final Future<DomainPublishResult> Function(int dds, int ros)?
      onDomainRemotePublish;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: LauncherTokens.fontBody,
        // 한글 글리프 폴백 — fontFamily 가 라틴 전용이어도 한글이 NotoSansKR 로 렌더.
        fontFamilyFallback: LauncherTokens.fontFallback,
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
        aiService: aiService,
        visibilityStore: visibilityStore,
        botAvailabilityProbe: botAvailabilityProbe,
        timezoneStore: timezoneStore,
        domainStore: domainStore,
        onDomainRemotePublish: onDomainRemotePublish,
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
    this.aiService,
    this.visibilityStore,
    this.botAvailabilityProbe,
    this.timezoneStore,
    this.domainStore,
    this.onDomainRemotePublish,
  });

  final PluginRegistry? initialRegistry;
  final bool enableRos;
  final AppPanelBuilder? panelBuilder;
  final LauncherBotAiService? aiService;

  /// F017: Optional visibility store override for tests.
  final AppVisibilityStore? visibilityStore;

  /// Optional launcher-bot availability probe override (tests).
  final BotAvailabilityProbe? botAvailabilityProbe;

  /// Optional timezone store override (tests).
  final TimezoneStore? timezoneStore;

  /// 통신 두 평면(DDS/ROS2) 도메인 설정 저장소. 테스트는 in-memory 를 주입한다.
  final DomainStore? domainStore;

  /// 원격 호스트(차량 컴퓨트)의 domain.env 갱신 요청. null 이면 rosbridge keeper 를
  /// 쓴다. 테스트는 가짜를 주입해 "로컬 저장값과 같은 값이 나가는지" 를 본다.
  final Future<DomainPublishResult> Function(int dds, int ros)?
      onDomainRemotePublish;

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  late final PluginRegistry _registry;
  late final AppVisibilityStore _visibilityStore;
  late final TimezoneStore _timezoneStore;
  late final DomainStore _domainStore;
  late LauncherConfig _launcherConfig;
  String _rosStatus = 'Loading';
  LauncherRosKeeper? _rosKeeper;
  Set<String> _runningAppIds = const {};

  @override
  void initState() {
    super.initState();
    _registry = widget.initialRegistry ??
        PluginRegistryScanner(
          appsRoot: resolveAppsRoot(),
          launcherVersion: launcherVersion,
        ).scan();
    // F017: Visibility store — production uses XDG_CONFIG_HOME / ~/.config.
    // Tests inject an in-memory store via widget.visibilityStore to avoid
    // file-system I/O and to exercise the full toggle→sidebar lifecycle.
    _visibilityStore = widget.visibilityStore ?? _resolveVisibilityStore();
    _visibilityStore.load(); // async, best-effort — UI starts with all enabled
    // Display timezone — defaults to Korea (KST). Tests inject in-memory.
    _timezoneStore = widget.timezoneStore ?? _resolveTimezoneStore();
    _timezoneStore.load(); // async, best-effort — UI starts on KST
    // 두 평면 도메인 — DDS(순수 Fast-DDS) / ROS2(rmw), 기본 둘 다 42 (Autoware adsw
    // 파티션과 동일). Settings 에서 바꾸면 도메인 파일(MMF_DOMAIN_ENV_FILE)에 두 키가
    // 기록되어 각 서비스는 다음 기동 때 반영한다.
    _domainStore = widget.domainStore ?? _resolveDomainStore();
    _domainStore.load(); // async, best-effort — UI starts on 42
    _launcherConfig = LauncherConfig.defaults();
    _loadConfigAndInitRos();
  }

  static AppVisibilityStore _resolveVisibilityStore() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return AppVisibilityStore.file('$xdg/hmi_launcher');
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return AppVisibilityStore.file('$home/.config/hmi_launcher');
    }
    return AppVisibilityStore.file('/var/lib/hmi_launcher');
  }

  /// 도메인 저장소 — 설정 JSON 은 XDG 아래, MMF 도메인 파일 경로는
  /// `MMF_DOMAIN_ENV_FILE` env 로 배포마다 바꿀 수 있다(기본 /opt/mmf/config/domain.env).
  static DomainStore _resolveDomainStore() {
    final envFile = Platform.environment['MMF_DOMAIN_ENV_FILE'];
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    final home = Platform.environment['HOME'];
    final dir = (xdg != null && xdg.isNotEmpty)
        ? '$xdg/hmi_launcher'
        : (home != null && home.isNotEmpty)
            ? '$home/.config/hmi_launcher'
            : '/var/lib/hmi_launcher';
    return DomainStore.file(
      dir,
      envFilePath: (envFile != null && envFile.isNotEmpty) ? envFile : null,
    );
  }

  static TimezoneStore _resolveTimezoneStore() {
    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return TimezoneStore.file('$xdg/hmi_launcher');
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return TimezoneStore.file('$home/.config/hmi_launcher');
    }
    return TimezoneStore.file('/var/lib/hmi_launcher');
  }

  /// L009: Initialize unified ROS keeper for embedded plugins.
  ///
  /// Creates a single Ros instance registered in GetX. All plugin collectors
  /// (OtaCollector, AdswCollector, etc.) will find this via `Get.find<Ros>()`.
  ///
  /// When enableRos=false (tests), a mock Ros is registered to prevent
  /// `Get.find<Ros>()` errors in collectors.
  Future<void> _loadConfigAndInitRos() async {
    final loadedConfig = await _LauncherConfigStore.load();
    if (!mounted) return;
    setState(() {
      _launcherConfig = loadedConfig;
      _rosStatus = widget.enableRos ? 'Configured' : 'Disabled';
    });
    _syncAppThemes(loadedConfig);
    _initRosSync();
  }

  void _initRosSync() {
    if (!widget.enableRos) {
      // Register mock Ros for tests to prevent Get.find<Ros>() errors
      _registerMockRos();
      return;
    }
    _rosKeeper = LauncherRosKeeper(_launcherConfig);
    _rosKeeper!.setRunningAppIds(_runningAppIds);
    // Start ROS asynchronously but don't await (collectors will handle connection state)
    _rosKeeper!.start();
  }

  Future<void> _applyRosBridge(Uri rosUrl) async {
    final nextConfig = LauncherConfig(
      rosUrl: rosUrl,
      statusTopic: _launcherConfig.statusTopic,
      rosReconnectIntervalSec: _launcherConfig.rosReconnectIntervalSec,
      heartbeatIntervalSec: _launcherConfig.heartbeatIntervalSec,
      otaTheme: _launcherConfig.otaTheme,
      adswTheme: _launcherConfig.adswTheme,
      diagTheme: _launcherConfig.diagTheme,
      lfcTheme: _launcherConfig.lfcTheme,
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
    _rosKeeper!.setRunningAppIds(_runningAppIds);
    await _rosKeeper!.start();
    if (mounted) setState(() => _rosStatus = 'Configured');
  }

  void _handleRunningAppIdsChanged(Set<String> appIds) {
    _runningAppIds = appIds;
    _rosKeeper?.setRunningAppIds(appIds);
  }

  Future<void> _applyAppTheme(String appId, String themeName) async {
    final normalized = themeName == 'dark' ? 'dark' : 'light';
    final nextConfig = LauncherConfig(
      rosUrl: _launcherConfig.rosUrl,
      statusTopic: _launcherConfig.statusTopic,
      rosReconnectIntervalSec: _launcherConfig.rosReconnectIntervalSec,
      heartbeatIntervalSec: _launcherConfig.heartbeatIntervalSec,
      otaTheme: appId == 'ota_monitor' ? normalized : _launcherConfig.otaTheme,
      adswTheme:
          appId == 'adsw_monitor' ? normalized : _launcherConfig.adswTheme,
      diagTheme:
          appId == 'diag_monitor' ? normalized : _launcherConfig.diagTheme,
      lfcTheme: appId == 'lfc_monitor' ? normalized : _launcherConfig.lfcTheme,
    );

    setState(() => _launcherConfig = nextConfig);
    _syncAppThemes(nextConfig);
    await _LauncherConfigStore.save(nextConfig);
  }

  void _syncAppThemes(LauncherConfig config) {
    ota_theme.paletteNotifier.value =
        ota_theme.Palette.fromName(config.otaTheme);
    adsw_theme.adswPaletteNotifier.value =
        adsw_theme.AdswPalette.fromName(config.adswTheme);
    diag_theme.diagPaletteNotifier.value =
        diag_theme.DiagPalette.fromName(config.diagTheme);
    lfc_theme.paletteNotifier.value =
        lfc_theme.LfcPalette.fromName(config.lfcTheme);
  }

  /// Registers a mock Ros instance for test environments.
  ///
  /// Plugin collectors call `Get.find<Ros>()` in their constructors.
  /// Without this, tests with enableRos=false would crash.
  void _registerMockRos() {
    if (Get.isRegistered<Ros>()) return; // Test may have injected one
    Get.put<Ros>(Ros(url: 'ws://mock:9090'));
  }

  @override
  void dispose() {
    // Only dispose the store when we created it (not when injected by caller).
    if (widget.visibilityStore == null) {
      _visibilityStore.dispose();
    }
    if (widget.timezoneStore == null) {
      _timezoneStore.dispose();
    }
    _rosKeeper?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LauncherBotShell(
      botAvailabilityProbe: widget.botAvailabilityProbe,
      registry: _registry,
      visibilityStore: _visibilityStore,
      timezoneStore: _timezoneStore,
      domainStore: _domainStore,
      // 도메인 저장 직후 같은 호스트의 MMF 컨테이너를 재시작한다. 런처 컨테이너는
      // docker.sock + docker CLI 를 갖고 있어(rviz2_panel 과 동일 경로) 가능하다.
      mmfRestarter: MmfRestarter(),
      panelBuilder: widget.panelBuilder,
      aiService: widget.aiService,
      rosUrl: _launcherConfig.rosUrl,
      rosStatus: widget.enableRos ? _rosStatus : 'Disabled',
      onRosUrlChanged: _applyRosBridge,
      otaTheme: _launcherConfig.otaTheme,
      adswTheme: _launcherConfig.adswTheme,
      diagTheme: _launcherConfig.diagTheme,
      lfcTheme: _launcherConfig.lfcTheme,
      onAppThemeChanged: _applyAppTheme,
      onServiceModeChanged: (modeValue) async =>
          lfc.applyGlobalServiceMode(modeValue),
      // 다른 호스트(차량 컴퓨트)의 domain.env 는 그쪽 domain_agent 만 쓸 수 있다 —
      // 런처는 rosbridge 로 요청만 보낸다. keeper 가 없으면(ROS 비활성) false.
      onDomainRemotePublish: widget.onDomainRemotePublish ??
          (dds, ros) async =>
              await _rosKeeper?.publishDomainRequest(dds: dds, ros: ros) ??
              DomainPublishResult.failed,
      onRunningAppIdsChanged: _handleRunningAppIdsChanged,
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
      'otaTheme': config.otaTheme,
      'adswTheme': config.adswTheme,
      'diagTheme': config.diagTheme,
      'lfcTheme': config.lfcTheme,
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
