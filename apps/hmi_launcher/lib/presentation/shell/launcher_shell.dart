import 'package:flutter/material.dart';
import '../../domain/plugin_registry.dart';
import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';
import 'launcher_titlebar.dart';
import 'launcher_sidebar.dart';
import 'launcher_statusbar.dart';
import 'launcher_promptbar.dart';
import 'launcher_app_area.dart';
import '../panels/launcher_home_panel.dart';

/// Root shell widget for AGL Launcher v2.
/// Composes titlebar, sidebar, statusbar, app area, and promptbar.
class LauncherShell extends StatefulWidget {
  const LauncherShell({
    super.key,
    required this.registry,
    this.initialAppId,
  });

  final PluginRegistry registry;
  final String? initialAppId;

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell> {
  late String? _selectedAppId;
  late NluRouter _nluRouter;

  // Callback to communicate prompt submission to home panel
  void Function(String input, AppManifest? matchedApp)? _homePanelPromptCallback;

  @override
  void initState() {
    super.initState();
    _selectedAppId = widget.initialAppId;
    _nluRouter = NluRouter(widget.registry.apps);
  }

  Color _getCurrentAccent() {
    if (_selectedAppId == null) {
      return LauncherTokens.launcher;
    }

    final app = widget.registry.apps.firstWhere(
      (a) => a.id == _selectedAppId,
      orElse: () => widget.registry.apps.first,
    );

    // Parse hex color from manifest
    final colorStr = app.color.replaceFirst('#', '');
    if (colorStr.length == 6) {
      return Color(int.parse('0xFF$colorStr'));
    }
    return LauncherTokens.launcher;
  }

  String _getCurrentAppName() {
    if (_selectedAppId == null) {
      return 'AGL LAUNCHER';
    }

    final app = widget.registry.apps.firstWhere(
      (a) => a.id == _selectedAppId,
      orElse: () => widget.registry.apps.first,
    );

    return '${app.icon} ${app.name}';
  }

  void _handleAppSelected(String? appId) {
    setState(() {
      _selectedAppId = appId;
    });
  }

  void _handleAppLaunch(AppManifest app) {
    setState(() {
      _selectedAppId = app.id;
    });
  }

  void _handlePromptSubmit(String input) {
    final matchedApp = _nluRouter.resolve(input);

    // If on home panel, notify it via callback
    if (_selectedAppId == null && _homePanelPromptCallback != null) {
      _homePanelPromptCallback!(input, matchedApp);
    }

    // Auto-launch if match found
    if (matchedApp != null) {
      Future.delayed(const Duration(milliseconds: 320), () {
        setState(() {
          _selectedAppId = matchedApp.id;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _getCurrentAccent();

    return AppAccentScope(
      accentColor: accent,
      child: Scaffold(
        key: const Key('launcher_shell'),
        backgroundColor: LauncherTokens.bg1,
        body: Column(
          children: [
            const LauncherTitleBar(),
            Expanded(
              child: Row(
                children: [
                  LauncherSidebar(
                    apps: widget.registry.apps,
                    selectedAppId: _selectedAppId,
                    onAppSelected: _handleAppSelected,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        LauncherStatusBar(
                          appName: _getCurrentAppName(),
                        ),
                        Expanded(
                          child: LauncherAppArea(
                            apps: widget.registry.apps,
                            selectedAppId: _selectedAppId,
                            onAppLaunch: _handleAppLaunch,
                            onHomePanelReady: (callback) {
                              _homePanelPromptCallback = callback;
                            },
                          ),
                        ),
                        LauncherPromptBar(
                          onSubmit: _handlePromptSubmit,
                        ),
                      ],
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
