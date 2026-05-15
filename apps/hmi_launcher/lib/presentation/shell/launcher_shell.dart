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
    this.panelBuilder,
  });

  final PluginRegistry registry;
  final String? initialAppId;

  /// Optional override for the plugin-panel factory. Forwarded to
  /// [LauncherAppArea]; tests inject a lightweight builder so the shell
  /// can be exercised without pulling in plugin internals.
  final AppPanelBuilder? panelBuilder;

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell> {
  late String? _selectedAppId;
  late NluRouter _nluRouter;
  bool _fullscreen = false;

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
    // While a plugin is open, offer a quick Close chip so the user can
    // return to home without reaching for the sidebar. Deeper per-app
    // chips (sensor health, "what's out of date?", ...) are Phase B.
    return const [
      PromptChip(label: 'Close app', query: 'close'),
    ];
  }

  String get _placeholder => _selectedAppId == null
      ? 'Ask AGL — "open OTA", "show sensor health"…'
      : 'Ask about ${_selectedApp!.name}…';

  void _handleAppSelected(String? appId) {
    setState(() {
      _selectedAppId = appId;
      // Leaving a plugin (back to home) always exits fullscreen so the
      // shell chrome is visible again.
      if (appId == null) _fullscreen = false;
    });
  }

  void _handleAppLaunch(AppManifest app) {
    setState(() => _selectedAppId = app.id);
  }

  void _setFullscreen(bool on) {
    if (_fullscreen == on) return;
    setState(() => _fullscreen = on);
  }

  /// Phrases that return the user to the home panel. Matched as whole
  /// queries so commands like "close ota monitor" still fall through to
  /// NLU routing (which would open OTA rather than close the current
  /// app).
  static const _closeCommands = {
    'close', 'close app', 'exit', 'exit app', 'quit', 'back',
    'home', 'go home', 'back to home',
    '홈', '홈으로', '닫기', '닫아', '닫아줘', '종료', '나가기', '뒤로',
    '뒤로 가기',
  };

  void _handlePromptSubmit(String input) {
    final lc = input.trim().toLowerCase();

    if (_closeCommands.contains(lc)) {
      if (_selectedAppId == null) {
        _showToast('Already on home');
        return;
      }
      final closing = _selectedApp?.name ?? 'app';
      setState(() {
        _selectedAppId = null;
        _fullscreen = false;
      });
      _showToast('Closed $closing');
      return;
    }

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
    final appArea = LauncherAppArea(
      apps: widget.registry.apps,
      selectedAppId: _selectedAppId,
      onAppLaunch: _handleAppLaunch,
      panelBuilder: widget.panelBuilder,
    );

    return AppAccentScope(
      accentColor: LauncherTokens.accent,
      child: Scaffold(
        key: const Key('launcher_shell'),
        backgroundColor: LauncherTokens.bg0,
        body: _fullscreen
            ? _buildFullscreen(appArea)
            : _buildWindowed(appArea),
      ),
    );
  }

  Widget _buildWindowed(Widget appArea) {
    // Fullscreen toggle is only meaningful while a plugin is mounted.
    final canFullscreen = _selectedAppId != null;
    return Column(
      children: [
        LauncherTitleBar(
          appTitle: _topTitle,
          appSub: _topSub,
          onEnterFullscreen:
              canFullscreen ? () => _setFullscreen(true) : null,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LauncherSidebar(
                apps: widget.registry.apps,
                selectedAppId: _selectedAppId,
                onAppSelected: _handleAppSelected,
              ),
              Expanded(child: appArea),
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
    );
  }

  Widget _buildFullscreen(Widget appArea) {
    // Immersive mode: hide topbar + sidebar, keep the prompt bar so users
    // can still voice/text-switch to another app. An exit affordance sits
    // top-right as an overlay.
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: appArea),
              Positioned(
                top: 12,
                right: 12,
                child: _FullscreenExitButton(
                  onTap: () => _setFullscreen(false),
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
    );
  }
}

/// Floating "exit fullscreen" pill shown in the top-right corner of the
/// immersive app view. Uses an elevated dark pill so it remains legible
/// over plugins of any background color.
class _FullscreenExitButton extends StatefulWidget {
  const _FullscreenExitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_FullscreenExitButton> createState() =>
      _FullscreenExitButtonState();
}

class _FullscreenExitButtonState extends State<_FullscreenExitButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          key: const Key('fullscreen_exit_button'),
          duration: const Duration(milliseconds: 330),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFF000000)
                : const Color(0xE6171A20),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.fullscreen_exit, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Exit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
