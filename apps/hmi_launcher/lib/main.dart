import 'package:flutter/material.dart';

import 'domain/app_manifest.dart';
import 'domain/nlu_router.dart';
import 'domain/plugin_registry.dart';
import 'presentation/layout/four_zone_layout.dart';
import 'presentation/widgets/app_launch_card.dart';
import 'presentation/widgets/prompt_input_bar.dart';
import 'presentation/widgets/sidebar_navigator.dart';

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
  const HmiLauncherApp({super.key, this.initialRegistry});

  /// Allows tests to inject a fixture registry so the UI doesn't depend on
  /// a real filesystem.
  final PluginRegistry? initialRegistry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF64748B),
        ),
      ),
      home: LauncherHomePage(initialRegistry: initialRegistry),
    );
  }
}

class LauncherHomePage extends StatefulWidget {
  const LauncherHomePage({super.key, this.initialRegistry});

  final PluginRegistry? initialRegistry;

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  late final PluginRegistry _registry;
  late final NluRouter _router;
  final TextEditingController _promptController = TextEditingController();

  /// Currently selected sidebar app (drives the highlight).
  String? _selectedAppId;

  /// Manifest resolved by the latest prompt submission — rendered as an
  /// AppLaunchCard in the main zone.
  AppManifest? _pendingLaunch;

  /// Transient informational message shown above the card (e.g. "no match").
  String? _message;

  @override
  void initState() {
    super.initState();
    _registry = widget.initialRegistry ??
        PluginRegistryScanner(
          appsRoot: appsRoot,
          launcherVersion: launcherVersion,
        ).scan();
    _router = NluRouter(_registry.apps);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _onPromptSubmitted(String text) {
    final match = _router.resolve(text);
    setState(() {
      if (match == null) {
        _pendingLaunch = null;
        _message = '"$text" 에 매칭되는 앱이 없습니다.';
      } else {
        _pendingLaunch = match;
        _selectedAppId = match.id;
        _message = null;
      }
    });
  }

  void _onSidebarSelected(AppManifest app) {
    setState(() {
      _selectedAppId = app.id;
      _pendingLaunch = app;
      _message = null;
    });
  }

  void _onLaunchConfirmed(AppManifest app) {
    // MVP: show a transient confirmation banner. L006/L007 will replace
    // this with real navigation into the embedded app route.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${app.name} 실행 (entry: ${app.entry})'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FourZoneLayout(
      topBar: const _LauncherTopBar(),
      sidebar: SidebarNavigator(
        apps: _registry.apps,
        selectedAppId: _selectedAppId,
        onAppSelected: _onSidebarSelected,
      ),
      main: _MainPane(
        pending: _pendingLaunch,
        message: _message,
        registryEmpty: _registry.apps.isEmpty,
        onLaunch: _onLaunchConfirmed,
      ),
      promptBar: PromptInputBar(
        controller: _promptController,
        onSubmitted: _onPromptSubmitted,
      ),
    );
  }
}

class _LauncherTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _LauncherTopBar();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF111827),
      elevation: 0,
      title: const Text(
        'AGL Launcher',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              'v$launcherVersion · MVP',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainPane extends StatelessWidget {
  const _MainPane({
    required this.pending,
    required this.message,
    required this.registryEmpty,
    required this.onLaunch,
  });

  final AppManifest? pending;
  final String? message;
  final bool registryEmpty;
  final ValueChanged<AppManifest> onLaunch;

  @override
  Widget build(BuildContext context) {
    if (registryEmpty && pending == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '등록된 앱이 없습니다.\n`apps/<app>/manifest.json` 을 추가한 뒤 런처를 재시작하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              message!,
              key: const Key('main_message'),
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ),
        if (pending != null)
          AppLaunchCard(
            app: pending!,
            onLaunch: () => onLaunch(pending!),
          )
        else if (message == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '어떤 앱을 실행할까요?',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 18),
            ),
          ),
      ],
    );
  }
}
