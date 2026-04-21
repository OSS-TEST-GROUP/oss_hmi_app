import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../panels/adsw_embedded_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/launcher_home_panel.dart';
import '../panels/ota_embedded_panel.dart';
import '../theme/launcher_tokens.dart';

/// App area that hosts either the home panel or an embedded plugin panel,
/// with a soft cross-fade when [selectedAppId] changes.
///
/// Future plugins not yet embedded fall back to [AppPlaceholderPanel].
class LauncherAppArea extends StatelessWidget {
  const LauncherAppArea({
    super.key,
    required this.apps,
    required this.selectedAppId,
    required this.onAppLaunch,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;

  @override
  Widget build(BuildContext context) {
    final Widget panel;
    final Key key;

    if (selectedAppId == null) {
      key = const ValueKey('home_panel');
      panel = LauncherHomePanel(
        key: key,
        apps: apps,
        onAppLaunch: onAppLaunch,
      );
    } else {
      final app = apps.firstWhere((a) => a.id == selectedAppId);
      key = ValueKey('panel_$selectedAppId');
      panel = _buildPanel(app, key);
    }

    return Container(
      key: const Key('launcher_app_area'),
      color: LauncherTokens.bg0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: panel,
      ),
    );
  }

  Widget _buildPanel(AppManifest app, Key key) {
    switch (app.id) {
      case 'ota_monitor':
        return OtaEmbeddedPanel(key: key);
      case 'adsw_monitor':
        return AdswEmbeddedPanel(key: key);
      default:
        return AppPlaceholderPanel(key: key, app: app);
    }
  }
}
