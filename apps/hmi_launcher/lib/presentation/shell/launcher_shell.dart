import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../../domain/plugin_registry.dart';
import '../theme/app_accent_scope.dart';
import '../theme/launcher_tokens.dart';
import 'launcher_app_area.dart';
import 'launcher_promptbar.dart';
import 'launcher_sidebar.dart';
import 'launcher_titlebar.dart';

/// Root shell for the Tesla-reskin launcher.
///
/// Layout: [top bar] · [ left rail | app view ] · [prompt bar].
/// All surfaces share a single Electric Blue accent exposed through
/// [AppAccentScope] so child widgets stay visually consistent.
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

  @override
  void initState() {
    super.initState();
    _selectedAppId = widget.initialAppId;
    _nluRouter = NluRouter(widget.registry.apps);
  }

  AppManifest? get _selectedApp {
    if (_selectedAppId == null) return null;
    for (final a in widget.registry.apps) {
      if (a.id == _selectedAppId) return a;
    }
    return null;
  }

  String get _topTitle => _selectedApp?.name ?? 'Launcher';

  String get _topSub {
    final app = _selectedApp;
    if (app == null) {
      final n = widget.registry.apps.length;
      return '$n ${n == 1 ? 'app' : 'apps'} installed';
    }
    return '${app.category} · v${app.version}';
  }

  List<PromptChip> get _chips {
    if (_selectedAppId == null) {
      return widget.registry.apps
          .take(4)
          .map((a) => PromptChip(label: 'Open ${a.name}', appId: a.id))
          .toList();
    }
    // Per-app chips are Phase B (sensor health, "what's out of date?", etc.).
    return const [];
  }

  String get _placeholder => _selectedAppId == null
      ? 'Ask AGL — "open OTA", "show sensor health"…'
      : 'Ask about ${_selectedApp!.name}…';

  void _handleAppSelected(String? appId) {
    setState(() => _selectedAppId = appId);
  }

  void _handleAppLaunch(AppManifest app) {
    setState(() => _selectedAppId = app.id);
  }

  void _handlePromptSubmit(String input) {
    final match = _nluRouter.resolve(input);
    if (match != null) {
      setState(() => _selectedAppId = match.id);
      _showToast('Opened ${match.name}');
      return;
    }
    final hints =
        widget.registry.apps.map((a) => a.name).take(3).join(', ');
    _showToast('"$input" — try: $hints');
  }

  void _handleChip(PromptChip chip) {
    if (chip.appId != null) {
      final app = widget.registry.apps.firstWhere(
        (a) => a.id == chip.appId,
        orElse: () => widget.registry.apps.first,
      );
      _handleAppLaunch(app);
      return;
    }
    if (chip.query != null) _handlePromptSubmit(chip.query!);
  }

  void _showToast(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: LauncherTokens.t1,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return AppAccentScope(
      accentColor: LauncherTokens.accent,
      child: Scaffold(
        key: const Key('launcher_shell'),
        backgroundColor: LauncherTokens.bg0,
        body: Column(
          children: [
            LauncherTitleBar(appTitle: _topTitle, appSub: _topSub),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LauncherSidebar(
                    apps: widget.registry.apps,
                    selectedAppId: _selectedAppId,
                    onAppSelected: _handleAppSelected,
                  ),
                  Expanded(
                    child: LauncherAppArea(
                      apps: widget.registry.apps,
                      selectedAppId: _selectedAppId,
                      onAppLaunch: _handleAppLaunch,
                    ),
                  ),
                ],
              ),
            ),
            LauncherPromptBar(
              chips: _chips,
              onChip: _handleChip,
              onSubmit: _handlePromptSubmit,
              placeholder: _placeholder,
            ),
          ],
        ),
      ),
    );
  }
}
