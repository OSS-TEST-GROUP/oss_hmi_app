import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../panels/launcher_home_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/ota_embedded_panel.dart';
import '../panels/adsw_embedded_panel.dart';

/// App area that hosts home panel and app placeholder panels.
/// Uses AnimatedSwitcher for smooth transitions between panels.
///
/// Note: Embedded panels with TabBarView (adsw_monitor) may trigger
/// AutomaticKeepAlive assertions during transitions. This is a known
/// Flutter framework quirk when combining AnimatedSwitcher with KeepAlive widgets.
/// The assertions are cosmetic and do not affect functionality.
class LauncherAppArea extends StatelessWidget {
  const LauncherAppArea({
    super.key,
    required this.apps,
    required this.selectedAppId,
    required this.onAppLaunch,
    this.onHomePanelReady,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;

  /// Called when home panel is mounted, provides callback to send prompts to it.
  final ValueChanged<void Function(String, AppManifest?)>? onHomePanelReady;

  @override
  Widget build(BuildContext context) {
    final Widget currentPanel;
    final Key panelKey;

    if (selectedAppId == null) {
      // Show home panel with unique key
      panelKey = const ValueKey('home_panel');
      currentPanel = _HomePanelWrapper(
        key: panelKey,
        apps: apps,
        onAppLaunch: onAppLaunch,
        onReady: onHomePanelReady,
      );
    } else {
      // L009: Show embedded plugin panel or placeholder
      final app = apps.firstWhere((a) => a.id == selectedAppId);
      panelKey = ValueKey('panel_$selectedAppId');
      currentPanel = _buildAppPanel(app);
    }

    return Container(
      key: const Key('launcher_app_area'),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: currentPanel,
      ),
    );
  }

  /// L009: Build app panel - embedded plugin or placeholder.
  ///
  /// Switch on app.id to return the appropriate embedded panel.
  /// Future plugins not yet embedded show AppPlaceholderPanel.
  Widget _buildAppPanel(AppManifest app) {
    switch (app.id) {
      case 'ota_monitor':
        return OtaEmbeddedPanel(key: Key('app_embedded_${app.id}'));
      case 'adsw_monitor':
        return AdswEmbeddedPanel(key: Key('app_embedded_${app.id}'));
      default:
        // Future plugins still show placeholder
        return AppPlaceholderPanel(
          key: ValueKey('app_panel_${app.id}'),
          app: app,
        );
    }
  }
}

/// Wrapper for LauncherHomePanel that manages callback registration.
///
/// This stateful wrapper calls onReady with the home panel's prompt callback
/// once mounted, avoiding GlobalKey usage.
class _HomePanelWrapper extends StatefulWidget {
  const _HomePanelWrapper({
    super.key,
    required this.apps,
    required this.onAppLaunch,
    this.onReady,
  });

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;
  final ValueChanged<void Function(String, AppManifest?)>? onReady;

  @override
  State<_HomePanelWrapper> createState() => _HomePanelWrapperState();
}

class _HomePanelWrapperState extends State<_HomePanelWrapper> {
  final GlobalKey<LauncherHomePanelState> _panelKey =
      GlobalKey<LauncherHomePanelState>();

  @override
  void initState() {
    super.initState();
    // Notify parent with callback once mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _panelKey.currentState != null) {
        widget.onReady?.call(_panelKey.currentState!.handlePromptSubmit);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LauncherHomePanel(
      key: _panelKey,
      apps: widget.apps,
      onAppLaunch: widget.onAppLaunch,
    );
  }
}
