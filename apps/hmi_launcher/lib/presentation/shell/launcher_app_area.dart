import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../panels/launcher_home_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/ota_embedded_panel.dart';
import '../panels/adsw_embedded_panel.dart';

/// App area that hosts home panel and app placeholder panels.
/// Uses AnimatedSwitcher for smooth transitions between panels.
class LauncherAppArea extends StatelessWidget {
  const LauncherAppArea({
    super.key,
    required this.apps,
    required this.selectedAppId,
    required this.onAppLaunch,
    this.homePanelKey,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;
  final GlobalKey<LauncherHomePanelState>? homePanelKey;

  @override
  Widget build(BuildContext context) {
    final Widget currentPanel;

    if (selectedAppId == null) {
      // Show home panel
      currentPanel = LauncherHomePanel(
        key: homePanelKey ?? const ValueKey('home_panel'),
        apps: apps,
        onAppLaunch: onAppLaunch,
      );
    } else {
      // L009: Show embedded plugin panel or placeholder
      final app = apps.firstWhere((a) => a.id == selectedAppId);
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
        return OtaEmbeddedPanel(key: ValueKey('app_embedded_${app.id}'));
      case 'adsw_monitor':
        return AdswEmbeddedPanel(key: ValueKey('app_embedded_${app.id}'));
      default:
        // Future plugins still show placeholder
        return AppPlaceholderPanel(
          key: ValueKey('app_panel_${app.id}'),
          app: app,
        );
    }
  }
}
