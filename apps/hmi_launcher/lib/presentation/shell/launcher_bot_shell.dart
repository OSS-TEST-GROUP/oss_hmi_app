import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../../domain/app_visibility_store.dart';
import '../../domain/nlu_router.dart';
import '../../domain/plugin_registry.dart';
import '../../launcher_bot/services/agent_submit_ai_service.dart';
import '../../launcher_bot/services/app_usage_store.dart';
import '../../launcher_bot/services/launcher_bot_ai_service.dart';
import '../../launcher_bot/services/launcher_bot_controller.dart';
import '../../launcher_bot/services/voice_input_service.dart';
import '../app_icon.dart';
import '../launcher_bot/launcher_bot_panel.dart';
import '../panels/adsw_embedded_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/lfc_embedded_panel.dart';
import '../panels/manage_apps_panel.dart';
import '../panels/ota_embedded_panel.dart';
import 'launcher_app_area.dart';

class LauncherBotShell extends StatefulWidget {
  const LauncherBotShell({
    super.key,
    required this.registry,
    required this.visibilityStore,
    required this.rosUrl,
    required this.rosStatus,
    required this.onRosUrlChanged,
    required this.otaTheme,
    required this.adswTheme,
    required this.lfcTheme,
    required this.onAppThemeChanged,
    this.onRunningAppIdsChanged,
    this.initialAppId,
    this.panelBuilder,
    this.aiService,
  });

  final PluginRegistry registry;

  /// Controls which apps are visible in the sidebar and home grid.
  /// Must outlive the shell widget — owned by the parent page.
  final AppVisibilityStore visibilityStore;

  final Uri rosUrl;
  final String rosStatus;
  final Future<void> Function(Uri rosUrl) onRosUrlChanged;
  final String otaTheme;
  final String adswTheme;
  final String lfcTheme;
  final Future<void> Function(String appId, String themeName) onAppThemeChanged;
  final ValueChanged<Set<String>>? onRunningAppIdsChanged;
  final String? initialAppId;
  final AppPanelBuilder? panelBuilder;

  /// Optional AI service override. When null the shell builds its own
  /// [AgentSubmitAiService] using AGENT_HOST / AGENT_PORT env-vars.
  ///
  /// Tests can inject a [FallbackLauncherBotAiService] (or any other
  /// implementation) to avoid real gRPC connections.
  final LauncherBotAiService? aiService;

  @override
  State<LauncherBotShell> createState() => _LauncherBotShellState();
}

class _LauncherBotShellState extends State<LauncherBotShell> {
  late String? _selectedAppId;
  late final List<String> _openedAppIds;
  late final List<String> _focusedAppIds;
  late NluRouter _nluRouter;
  late LauncherBotController _launcherBotController;
  final AppUsageStore _usageStore = AppUsageStore();
  final VoiceInputService _voiceInputService = const VoiceInputService();
  VoiceCaptureSession? _voiceSession;
  // F015: _aiSdkAvailable は gRPC 씬 클라이언트 가용성을 나타낸다.
  // 내장 LLM FFI 는 제거됐으며 gRPC Agent.Submit 이 주 AI 백엔드다.
  // 서버 미기동 시 NLU substring 폴백으로 이행한다 (AC3).
  late final bool _aiSdkAvailable;
  late bool _aiMode;
  String? _usageFocusAppId;
  DateTime? _usageFocusStartedAt;
  bool _assistantOpen = false;
  bool _voiceCapturing = false;
  bool _usageSuggestionShown = false;
  bool _manageAppsOpen = false;

  /// Apps that are both compatible with this launcher version and currently
  /// enabled in [AppVisibilityStore].  This is the list rendered in the
  /// sidebar and home grid.
  List<AppManifest> get _visibleApps => widget.registry.apps
      .where((app) => widget.visibilityStore.isEnabled(app.id))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _selectedAppId = widget.initialAppId;
    _openedAppIds = [
      if (widget.initialAppId != null) widget.initialAppId!,
    ];
    _focusedAppIds = [
      if (widget.initialAppId != null) widget.initialAppId!,
    ];
    _startUsageFocus(_selectedAppId);

    // F015: Agent.Submit gRPC 씬 클라이언트를 주 AI 서비스로 사용한다.
    // 환경변수 AGENT_HOST / AGENT_PORT 가 없으면 기본값(localhost:50051)을 사용한다.
    // gRPC 연결 가능 여부와 무관하게 UI 는 정상 기동한다 (AC4 rosbridge 독립 패턴 적용).
    // 테스트는 widget.aiService 를 통해 FallbackLauncherBotAiService 를 주입하여
    // 실제 gRPC 연결 없이 NLU 폴백만으로 동작할 수 있다.
    final agentHost = _resolveAgentHost();
    final agentPort = _resolveAgentPort();
    _aiSdkAvailable = true; // gRPC 씬 클라이언트는 항상 준비됨 — 연결 실패는 런타임 폴백 처리
    _aiMode = _aiSdkAvailable;

    _nluRouter = NluRouter(_visibleApps);
    _launcherBotController = LauncherBotController(
      nluRouter: _nluRouter,
      // F015: gRPC 씬 클라이언트. 연결 실패 시 NLU 폴백 (AC3) 은 LauncherBotController 에서 처리.
      // 테스트에서는 widget.aiService 를 통해 빠른 응답 서비스를 주입 가능.
      aiService: widget.aiService ??
          AgentSubmitAiService(
            host: agentHost,
            port: agentPort,
          ),
      onOpenApp: _openApp,
      onCloseApp: _closeApp,
      onOpenSettings: _openSettings,
    );
    // Rebuild whenever visibility changes so sidebar + home react instantly.
    widget.visibilityStore.addListener(_onVisibilityChanged);
    _notifyRunningAppIdsChanged();
    _loadUsageAndSuggest();
  }

  void _onVisibilityChanged() {
    _nluRouter = NluRouter(_visibleApps);
    _launcherBotController.updateRouter(_nluRouter);
    // If the currently selected app was hidden, go home.
    final current = _selectedAppId;
    if (current != null &&
        current != _SettingsPage.appId &&
        !_visibleApps.any((app) => app.id == current)) {
      _openedAppIds.remove(current);
      _focusedAppIds.remove(current);
      _selectedAppId = _focusedAppIds.isEmpty ? null : _focusedAppIds.last;
    }
    _notifyRunningAppIdsChanged();
    setState(() {});
  }

  /// Resolves the Agent gRPC server hostname from the environment.
  ///
  /// Priority: AGENT_HOST env var → 'localhost'.
  static String _resolveAgentHost() {
    const agentHost = String.fromEnvironment('AGENT_HOST', defaultValue: '');
    return agentHost.trim().isNotEmpty ? agentHost : 'localhost';
  }

  /// Resolves the Agent gRPC server port from the environment.
  ///
  /// Priority: AGENT_PORT env var → 50051.
  static int _resolveAgentPort() {
    const portStr =
        String.fromEnvironment('AGENT_PORT', defaultValue: '50051');
    return int.tryParse(portStr.trim()) ?? 50051;
  }

  @override
  void didUpdateWidget(covariant LauncherBotShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibilityStore != widget.visibilityStore) {
      oldWidget.visibilityStore.removeListener(_onVisibilityChanged);
      widget.visibilityStore.addListener(_onVisibilityChanged);
    }
    if (oldWidget.registry != widget.registry ||
        oldWidget.visibilityStore != widget.visibilityStore) {
      _nluRouter = NluRouter(_visibleApps);
      _launcherBotController.updateRouter(_nluRouter);
      final validIds = _visibleApps.map((app) => app.id).toSet()
        ..add(_SettingsPage.appId);
      _openedAppIds.removeWhere((id) => !validIds.contains(id));
      _focusedAppIds.removeWhere((id) => !validIds.contains(id));
      if (_selectedAppId != null && !validIds.contains(_selectedAppId)) {
        _selectedAppId = _focusedAppIds.isEmpty ? null : _focusedAppIds.last;
      }
      _notifyRunningAppIdsChanged();
    }
  }

  @override
  void dispose() {
    widget.visibilityStore.removeListener(_onVisibilityChanged);
    _flushUsageFocus();
    _voiceSession?.stop();
    _launcherBotController.dispose();
    super.dispose();
  }

  AppManifest? get _selectedApp {
    final id = _selectedAppId;
    if (id == null) return null;
    for (final app in _visibleApps) {
      if (app.id == id) return app;
    }
    return null;
  }

  String get _title => _selectedApp?.name ?? 'Launcher';

  String get _subtitle {
    final app = _selectedApp;
    if (app == null) return 'Home surface';
    return '${app.category} · v${app.version}';
  }

  void _setAiMode(bool value) {
    if (value && !_aiSdkAvailable) return;
    setState(() => _aiMode = value);
    if (value) unawaited(_maybeSuggestFrequentApp());
  }

  void _selectOpenedApp(String appId) {
    _flushUsageFocus();
    if (!_openedAppIds.contains(appId)) {
      _openedAppIds.add(appId);
    }
    _focusedAppIds.remove(appId);
    _focusedAppIds.add(appId);
    _selectedAppId = appId;
    _startUsageFocus(_selectedAppId);
    _notifyRunningAppIdsChanged();
  }

  void _notifyRunningAppIdsChanged() {
    final appIds = _visibleApps.map((app) => app.id).toSet();
    widget.onRunningAppIdsChanged?.call({
      for (final id in _openedAppIds)
        if (appIds.contains(id)) id,
    });
  }

  void _openApp(AppManifest app) {
    unawaited(_usageStore.recordOpen(app.id));
    setState(() => _selectOpenedApp(app.id));
  }

  void _openSettings() {
    _flushUsageFocus();
    setState(() => _selectOpenedApp(_SettingsPage.appId));
  }

  void _goHome() {
    if (_selectedAppId == null) return;
    _flushUsageFocus();
    setState(() => _selectedAppId = null);
  }

  Future<void> _restartLauncher() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Launcher'),
        content: const Text('런처를 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    exit(0);
  }

  void _startUsageFocus(String? appId) {
    if (appId == null ||
        !_visibleApps.any((app) => app.id == appId)) {
      _usageFocusAppId = null;
      _usageFocusStartedAt = null;
      return;
    }
    _usageFocusAppId = appId;
    _usageFocusStartedAt = DateTime.now();
  }

  void _flushUsageFocus() {
    final appId = _usageFocusAppId;
    final startedAt = _usageFocusStartedAt;
    _usageFocusAppId = null;
    _usageFocusStartedAt = null;

    if (appId == null || startedAt == null) return;
    final duration = DateTime.now().difference(startedAt);
    unawaited(_usageStore.recordForegroundDuration(appId, duration));
  }

  Future<void> _loadUsageAndSuggest() async {
    await _usageStore.load();
    if (!mounted) return;
    await _maybeSuggestFrequentApp();
  }

  Future<void> _maybeSuggestFrequentApp() async {
    if (_usageSuggestionShown || !_aiSdkAvailable || !_aiMode) {
      debugPrint(
        '[LauncherBotShell] suggestion skip: '
        'shown=$_usageSuggestionShown aiAvailable=$_aiSdkAvailable aiMode=$_aiMode',
      );
      return;
    }
    if (_selectedAppId != null || _visibleApps.isEmpty) {
      debugPrint(
        '[LauncherBotShell] suggestion skip: '
        'selected=$_selectedAppId appCount=${_visibleApps.length}',
      );
      return;
    }

    final usages = _usageStore.suggestionCandidates(
      _visibleApps.map((app) => app.id).toSet(),
    );
    if (usages.isEmpty) {
      debugPrint('[LauncherBotShell] suggestion skip: no usage candidates');
      return;
    }

    debugPrint(
      '[LauncherBotShell] suggestion candidates: '
      '${usages.map((usage) => '${usage.appId}(open=${usage.openCount}, dwell=${usage.totalForegroundSeconds}s, last=${usage.lastOpenedAt.toIso8601String()})').join(', ')}',
    );

    final shown = await _launcherBotController.suggestFrequentApp(
      usages: usages,
    );
    if (!mounted) return;
    _usageSuggestionShown = shown;
    debugPrint('[LauncherBotShell] suggestion shown=$shown');
    if (shown) {
      setState(() => _assistantOpen = true);
    }
  }

  Future<void> _handleVoiceCommand() async {
    if (!_aiMode || !_aiSdkAvailable) return;

    final activeSession = _voiceSession;
    if (activeSession != null) {
      _showSnackBar('이미 음성을 듣고 있어요. 10초 녹음 후 자동으로 처리합니다.');
      return;
    }
    if (_voiceCapturing) return;

    setState(() {
      _voiceCapturing = true;
      _assistantOpen = true;
    });
    _showSnackBar('음성을 듣고 있어요.');

    try {
      final session = await _voiceInputService.startCapture();
      if (!mounted) {
        session.stop();
        return;
      }
      setState(() => _voiceSession = session);
      _finishVoiceCapture(session);
    } on VoiceInputException catch (error) {
      _showSnackBar(error.message);
      if (mounted) {
        setState(() => _voiceCapturing = false);
      }
    } catch (error) {
      _showSnackBar('음성 입력 처리에 실패했습니다. $error');
      if (mounted) {
        setState(() => _voiceCapturing = false);
      }
    }
  }

  Future<void> _finishVoiceCapture(VoiceCaptureSession session) async {
    try {
      final voice = await session.result;
      if (!mounted) return;
      if (_voiceSession == session) {
        setState(() {
          _voiceSession = null;
          _voiceCapturing = false;
        });
      }
      await _launcherBotController.submitVoice(voice);
    } on VoiceInputException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('음성 입력 처리에 실패했습니다. $error');
    } finally {
      if (mounted && _voiceSession == session) {
        setState(() {
          _voiceSession = null;
          _voiceCapturing = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String? _closeApp() {
    String? closedName;
    setState(() {
      final current = _selectedAppId;
      if (current == null) {
        return;
      }
      _flushUsageFocus();
      closedName = current == _SettingsPage.appId
          ? 'Settings'
          : widget.registry.findById(current)?.name;
      _openedAppIds.remove(current);
      _focusedAppIds.remove(current);
      _selectedAppId = _focusedAppIds.isEmpty ? null : _focusedAppIds.last;
      _startUsageFocus(_selectedAppId);
      _notifyRunningAppIdsChanged();
    });
    return closedName;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedApp;
    final settingsOpen = _selectedAppId == _SettingsPage.appId;
    final canClose = selected != null || settingsOpen;
    final selectedName =
        settingsOpen ? 'Settings' : selected?.name ?? 'Launcher';
    _launcherBotController.updateContext(selectedName);

    // Manage Apps panel replaces the main content area when open.
    if (_manageAppsOpen) {
      return Scaffold(
        key: const Key('launcher_bot_shell'),
        backgroundColor: _BotColors.canvas,
        body: SafeArea(
          child: ManageAppsPanel(
            allApps: widget.registry.apps,
            store: widget.visibilityStore,
            onClose: () => setState(() => _manageAppsOpen = false),
          ),
        ),
      );
    }

    return Scaffold(
      key: const Key('launcher_bot_shell'),
      backgroundColor: _BotColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: settingsOpen ? 'Settings' : _title,
              subtitle: settingsOpen ? 'System setup' : _subtitle,
              icon: settingsOpen
                  ? Icons.settings_outlined
                  : LauncherAppIcons.forId(selected?.id),
              aiMode: _aiMode,
              aiSdkAvailable: _aiSdkAvailable,
              canClose: canClose,
              onClose: _closeApp,
              onRestart: _restartLauncher,
              onModeChanged: _setAiMode,
              onManageApps: () => setState(() => _manageAppsOpen = true),
            ),
            Expanded(
              child: Row(
                children: [
                  _AppRail(
                    apps: _visibleApps,
                    openedAppIds: _openedAppIds,
                    selectedAppId: _selectedAppId,
                    aiMode: _aiMode,
                    aiSdkAvailable: _aiSdkAvailable,
                    voiceCapturing: _voiceCapturing,
                    assistantOpen: _assistantOpen,
                    onHomeSelected: _goHome,
                    onAppSelected: (appId) {
                      setState(() => _selectOpenedApp(appId));
                    },
                    onVoiceCommand: _handleVoiceCommand,
                    onAssistantToggle: () {
                      setState(() => _assistantOpen = !_assistantOpen);
                    },
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: _assistantOpen ? 440 : 0,
                    child: ClipRect(
                      child: LauncherBotPanel(
                        controller: _launcherBotController,
                        selectedName: selectedName,
                        aiMode: _aiMode && _aiSdkAvailable,
                        apps: _visibleApps,
                        onClose: () => setState(() => _assistantOpen = false),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _AppStage(
                      apps: _visibleApps,
                      openedAppIds: _openedAppIds,
                      selectedAppId: _selectedAppId,
                      panelBuilder: widget.panelBuilder,
                      onAppLaunch: _openApp,
                      onSettingsLaunch: _openSettings,
                      rosUrl: widget.rosUrl,
                      rosStatus: widget.rosStatus,
                      onRosUrlChanged: widget.onRosUrlChanged,
                      otaTheme: widget.otaTheme,
                      adswTheme: widget.adswTheme,
                      lfcTheme: widget.lfcTheme,
                      aiSdkAvailable: _aiSdkAvailable,
                      onAppThemeChanged: widget.onAppThemeChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppStage extends StatelessWidget {
  const _AppStage({
    required this.apps,
    required this.openedAppIds,
    required this.selectedAppId,
    required this.onAppLaunch,
    required this.onSettingsLaunch,
    required this.rosUrl,
    required this.rosStatus,
    required this.onRosUrlChanged,
    required this.otaTheme,
    required this.adswTheme,
    required this.lfcTheme,
    required this.aiSdkAvailable,
    required this.onAppThemeChanged,
    this.panelBuilder,
  });

  final List<AppManifest> apps;
  final List<String> openedAppIds;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;
  final VoidCallback onSettingsLaunch;
  final Uri rosUrl;
  final String rosStatus;
  final Future<void> Function(Uri rosUrl) onRosUrlChanged;
  final String otaTheme;
  final String adswTheme;
  final String lfcTheme;
  final bool aiSdkAvailable;
  final Future<void> Function(String appId, String themeName) onAppThemeChanged;
  final AppPanelBuilder? panelBuilder;

  @override
  Widget build(BuildContext context) {
    final visibleIds = _visibleOpenedAppIds();
    final selectedIndex =
        selectedAppId == null ? 0 : 1 + visibleIds.indexOf(selectedAppId!);

    return Container(
      key: const Key('launcher_app_area'),
      color: _BotColors.canvas,
      child: IndexedStack(
        index: selectedIndex < 0 ? 0 : selectedIndex,
        children: [
          _HomeSurface(
            key: const ValueKey('home_panel'),
            apps: apps,
            onAppLaunch: onAppLaunch,
            onSettingsLaunch: onSettingsLaunch,
          ),
          for (final appId in visibleIds) _buildPanel(appId),
        ],
      ),
    );
  }

  List<String> _visibleOpenedAppIds() {
    final appIds = apps.map((app) => app.id).toSet();
    return [
      for (final id in openedAppIds)
        if (id == _SettingsPage.appId || appIds.contains(id)) id,
    ];
  }

  Widget _buildPanel(String appId) {
    if (appId == _SettingsPage.appId) {
      return _SettingsPage(
        key: const ValueKey('settings_panel'),
        rosUrl: rosUrl,
        rosStatus: rosStatus,
        onRosUrlChanged: onRosUrlChanged,
        otaTheme: otaTheme,
        adswTheme: adswTheme,
        lfcTheme: lfcTheme,
        aiSdkAvailable: aiSdkAvailable,
        onAppThemeChanged: onAppThemeChanged,
      );
    }

    final app = apps.firstWhere((a) => a.id == appId);
    final key = Key('app_embedded_${app.id}');
    if (panelBuilder != null) {
      return KeyedSubtree(key: key, child: panelBuilder!(app));
    }
    switch (app.id) {
      case 'ota_monitor':
        return OtaEmbeddedPanel(key: key);
      case 'adsw_monitor':
        return AdswEmbeddedPanel(key: key);
      case 'lfc_monitor':
        return LfcEmbeddedPanel(key: key);
      default:
        return AppPlaceholderPanel(key: key, app: app);
    }
  }
}

class _HomeSurface extends StatelessWidget {
  const _HomeSurface({
    super.key,
    required this.apps,
    required this.onAppLaunch,
    required this.onSettingsLaunch,
  });

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;
  final VoidCallback onSettingsLaunch;

  /// Returns the greeting based on the current hour.
  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final app in apps) _LauncherCardData.fromApp(app),
      const _LauncherCardData.settings(),
    ];

    final appCount = apps.length;

    return Container(
      key: const Key('launcher_home_panel'),
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting header — matches the text that widget tests look for.
          Text(
            _greeting(),
            key: const Key('home_greeting'),
            style: const TextStyle(
              color: _BotColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$appCount ${appCount == 1 ? 'app' : 'apps'} installed',
            key: const Key('home_app_count'),
            style: const TextStyle(
              color: _BotColors.muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 780
                    ? 2
                    : constraints.maxWidth < 1120
                        ? 3
                        : 4;
                return GridView.builder(
                  key: const Key('launcher_home_grid'),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 2.05,
                  ),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _AppCard(
                      data: card,
                      onTap: () {
                        if (card.app != null) {
                          onAppLaunch(card.app!);
                        } else {
                          onSettingsLaunch();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    super.key,
    required this.rosUrl,
    required this.rosStatus,
    required this.onRosUrlChanged,
    required this.otaTheme,
    required this.adswTheme,
    required this.lfcTheme,
    required this.aiSdkAvailable,
    required this.onAppThemeChanged,
  });

  static const appId = LauncherAppIcons.settingsAppId;

  final Uri rosUrl;
  final String rosStatus;
  final Future<void> Function(Uri rosUrl) onRosUrlChanged;
  final String otaTheme;
  final String adswTheme;
  final String lfcTheme;
  final bool aiSdkAvailable;
  final Future<void> Function(String appId, String themeName) onAppThemeChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _bridgeIpController;
  late final TextEditingController _portController;
  late final TextEditingController _vehicleProfileController;
  String? _errorText;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _bridgeIpController = TextEditingController(text: widget.rosUrl.host);
    _portController = TextEditingController(
      text: widget.rosUrl.hasPort ? '${widget.rosUrl.port}' : '9090',
    );
    _vehicleProfileController = TextEditingController(text: 'AGL demo target');
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rosUrl != widget.rosUrl) {
      _bridgeIpController.text = widget.rosUrl.host;
      _portController.text =
          widget.rosUrl.hasPort ? '${widget.rosUrl.port}' : '9090';
    }
  }

  @override
  void dispose() {
    _bridgeIpController.dispose();
    _portController.dispose();
    _vehicleProfileController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final host = _bridgeIpController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      setState(() => _errorText = 'Enter a valid bridge IP and port.');
      return;
    }

    setState(() {
      _applying = true;
      _errorText = null;
    });
    try {
      await widget.onRosUrlChanged(Uri.parse('ws://$host:$port'));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _BotColors.canvas,
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _SettingsPanel(
                title: 'Connection',
                children: [
                  _SettingField(
                    label: 'Bridge IP address',
                    controller: _bridgeIpController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingField(
                    label: 'Port',
                    controller: _portController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _SettingField(
                    label: 'Vehicle profile',
                    controller: _vehicleProfileController,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _applying ? null : _apply,
                      icon: _applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_applying ? 'Applying' : 'Apply'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _SettingsPanel(
                    title: 'App Theme',
                    children: [
                      _ThemeSettingRow(
                        label: 'OTA Monitor',
                        value: widget.otaTheme,
                        onChanged: (theme) =>
                            widget.onAppThemeChanged('ota_monitor', theme),
                      ),
                      const SizedBox(height: 12),
                      _ThemeSettingRow(
                        label: 'AD SW',
                        value: widget.adswTheme,
                        onChanged: (theme) =>
                            widget.onAppThemeChanged('adsw_monitor', theme),
                      ),
                      const SizedBox(height: 12),
                      _ThemeSettingRow(
                        label: 'Lifecycle Monitor',
                        value: widget.lfcTheme,
                        onChanged: (theme) =>
                            widget.onAppThemeChanged('lfc_monitor', theme),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsPanel(
                    title: 'Runtime',
                    children: [
                      _SettingStatus(
                        label: 'AI SDK',
                        value: widget.aiSdkAvailable ? 'Enabled' : 'Disabled',
                      ),
                      const SizedBox(height: 10),
                      _SettingStatus(
                        label: 'ROS bridge',
                        value: widget.rosStatus,
                      ),
                      const SizedBox(height: 10),
                      const _SettingStatus(
                        label: 'Input method',
                        value: 'Shared',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.aiMode,
    required this.aiSdkAvailable,
    required this.canClose,
    required this.onClose,
    required this.onRestart,
    required this.onModeChanged,
    required this.onManageApps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool aiMode;
  final bool aiSdkAvailable;
  final bool canClose;
  final VoidCallback onClose;
  final VoidCallback onRestart;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onManageApps;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: _BotColors.surface,
        border: Border(bottom: BorderSide(color: _BotColors.line)),
      ),
      child: Row(
        children: [
          const Text(
            'AGL',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 4.2,
              color: _BotColors.ink,
            ),
          ),
          const SizedBox(width: 18),
          Container(width: 1, height: 24, color: _BotColors.line),
          const SizedBox(width: 18),
          Icon(icon, size: 20, color: _BotColors.ink),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BotColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _BotColors.muted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (canClose) ...[
            _CloseAppButton(onTap: onClose),
            const SizedBox(width: 10),
          ],
          _RestartLauncherButton(onTap: onRestart),
          const SizedBox(width: 10),
          // F017: Manage Apps entry point in the top bar grid area.
          _ManageAppsButton(onTap: onManageApps),
          const SizedBox(width: 10),
          _ModeButton(
            label: 'Standard',
            active: !aiMode,
            onTap: () => onModeChanged(false),
          ),
          const SizedBox(width: 8),
          _ModeButton(
            label: 'AI SDK',
            active: aiMode,
            enabled: aiSdkAvailable,
            onTap: () => onModeChanged(true),
          ),
        ],
      ),
    );
  }
}

class _AppRail extends StatelessWidget {
  const _AppRail({
    required this.apps,
    required this.openedAppIds,
    required this.selectedAppId,
    required this.aiMode,
    required this.aiSdkAvailable,
    required this.voiceCapturing,
    required this.assistantOpen,
    required this.onHomeSelected,
    required this.onAppSelected,
    required this.onVoiceCommand,
    required this.onAssistantToggle,
  });

  final List<AppManifest> apps;
  final List<String> openedAppIds;
  final String? selectedAppId;
  final bool aiMode;
  final bool aiSdkAvailable;
  final bool voiceCapturing;
  final bool assistantOpen;
  final VoidCallback onHomeSelected;
  final ValueChanged<String> onAppSelected;
  final VoidCallback onVoiceCommand;
  final VoidCallback onAssistantToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: const BoxDecoration(
        color: _BotColors.rail,
        border: Border(right: BorderSide(color: _BotColors.line)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Home button — always visible so tests (and users) can
                  // return to the home panel at any time.
                  _RailActionButton(
                    key: const Key('sidebar_item_home'),
                    icon: Icons.home_outlined,
                    enabled: true,
                    active: selectedAppId == null,
                    tooltip: 'Home',
                    onTap: onHomeSelected,
                  ),
                  const SizedBox(height: 8),
                  // All installed apps — not just the ones currently open.
                  // This mirrors LauncherSidebar behaviour so widget tests
                  // can tap sidebar_item_<id> without having to open the app
                  // first.
                  for (final app in apps) ...[
                    _RailAppButton(
                      key: Key('sidebar_item_${app.id}'),
                      icon: LauncherAppIcons.forId(app.id),
                      color: _parseHex(app.color),
                      tooltip: app.name,
                      active: selectedAppId == app.id,
                      onTap: () => onAppSelected(app.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RailActionButton(
            icon: Icons.mic_none,
            enabled: false,
            active: false,
            tooltip: 'Voice command is disabled',
            onTap: onVoiceCommand,
          ),
          const SizedBox(height: 8),
          _RailActionButton(
            key: const Key('assistant_toggle'),
            iconWidget: assistantOpen
                ? Transform.flip(
                    flipX: true,
                    child: const Icon(
                      Icons.start_outlined,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.chat_bubble_outline_rounded),
            active: assistantOpen,
            enabled: true,
            tooltip: assistantOpen ? 'Hide Launcher Bot' : 'Open Launcher Bot',
            onTap: onAssistantToggle,
          ),
          //const SizedBox(height: 8),
          //const _RailUtility(icon: Icons.power_settings_new),
        ],
      ),
    );
  }
}

class _RailAppButton extends StatelessWidget {
  const _RailAppButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          height: 50,
          decoration: BoxDecoration(
            color: active ? _BotColors.ink : _BotColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? _BotColors.ink : _BotColors.line,
            ),
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : color,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.data, required this.onTap});

  final _LauncherCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('home_cat_card_${data.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _BotColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _BotColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Icon(data.icon, color: data.color, size: 30),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BotColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BotColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _BotColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _BotColors.surface,
        border: Border.all(color: _BotColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _BotColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  const _SettingField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: Key('settings_field_$label'),
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.keyboard_outlined),
        filled: true,
        fillColor: _BotColors.canvas,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BotColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BotColors.accent),
        ),
      ),
    );
  }
}

class _ThemeSettingRow extends StatelessWidget {
  const _ThemeSettingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _BotColors.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _BotColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _ThemeChoice(
            label: 'Light',
            selected: value == 'light',
            onTap: () => onChanged('light'),
          ),
          const SizedBox(width: 6),
          _ThemeChoice(
            label: 'Dark',
            selected: value == 'dark',
            onTap: () => onChanged('dark'),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: 72,
      child: TextButton(
        onPressed: selected ? null : onTap,
        style: TextButton.styleFrom(
          backgroundColor: selected ? _BotColors.ink : _BotColors.surface,
          foregroundColor: selected ? _BotColors.surface : _BotColors.muted,
          disabledBackgroundColor: _BotColors.ink,
          disabledForegroundColor: _BotColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SettingStatus extends StatelessWidget {
  const _SettingStatus({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _BotColors.canvas,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _BotColors.line),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _BotColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: _BotColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 36,
        width: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _BotColors.ink : _BotColors.canvas,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? _BotColors.ink : _BotColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? _BotColors.muted.withValues(alpha: 0.42)
                : active
                    ? Colors.white
                    : _BotColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RailActionButton extends StatelessWidget {
  const _RailActionButton({
    super.key,
    this.icon,
    this.iconWidget,
    required this.enabled,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final bool active;
  final bool enabled;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = enabled
        ? active
            ? _BotColors.ink
            : _BotColors.surface
        : _BotColors.canvas;
    final fg = enabled
        ? active
            ? Colors.white
            : _BotColors.ink
        : _BotColors.muted.withValues(alpha: 0.42);
    final borderColor =
        enabled ? (active ? _BotColors.ink : _BotColors.line) : _BotColors.line;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 60,
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: iconWidget ?? Icon(icon, color: fg, size: 24),
        ),
      ),
    );
  }
}

class _CloseAppButton extends StatelessWidget {
  const _CloseAppButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close app',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _BotColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _BotColors.line),
          ),
          child: const Icon(Icons.close, color: _BotColors.ink, size: 22),
        ),
      ),
    );
  }
}

class _RestartLauncherButton extends StatelessWidget {
  const _RestartLauncherButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Restart launcher',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _BotColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _BotColors.line),
          ),
          child: const Icon(
            Icons.restart_alt,
            color: _BotColors.ink,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// F017: Button that opens the Manage Apps panel.
class _ManageAppsButton extends StatelessWidget {
  const _ManageAppsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Manage Apps',
      child: InkWell(
        key: const Key('manage_apps_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _BotColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _BotColors.line),
          ),
          child: const Icon(
            Icons.apps,
            color: _BotColors.ink,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _LauncherCardData {
  const _LauncherCardData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.app,
  });

  factory _LauncherCardData.fromApp(AppManifest app) {
    return _LauncherCardData(
      id: app.id,
      name: app.name,
      subtitle: app.category,
      icon: LauncherAppIcons.forApp(app),
      color: _parseHex(app.color),
      app: app,
    );
  }

  const _LauncherCardData.settings()
      : id = _SettingsPage.appId,
        name = 'Settings',
        subtitle = 'System setup',
        icon = LauncherAppIcons.settings,
        color = _BotColors.ink,
        app = null;

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final AppManifest? app;
}

Color _parseHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  if (normalized.length != 6) return _BotColors.accent;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return _BotColors.accent;
  return Color(0xFF000000 | value);
}

abstract final class _BotColors {
  static const canvas = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const rail = Color(0xFFE8ECF1);
  static const ink = Color(0xFF15191F);
  static const muted = Color(0xFF65707C);
  static const line = Color(0xFFDDE3EA);
  static const accent = Color(0xFF2E6BE6);
}
