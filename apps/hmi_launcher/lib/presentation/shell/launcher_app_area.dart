import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../panels/launcher_home_panel.dart';
import '../panels/app_placeholder_panel.dart';

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
      // Show app placeholder panel
      final app = apps.firstWhere((a) => a.id == selectedAppId);
      currentPanel = AppPlaceholderPanel(
        key: ValueKey('app_panel_$selectedAppId'),
        app: app,
      );
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
}
