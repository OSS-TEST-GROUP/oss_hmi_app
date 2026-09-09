import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../panels/adsw_embedded_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/diag_embedded_panel.dart';
import '../panels/launcher_home_panel.dart';
import '../panels/lfc_embedded_panel.dart';
import '../panels/ota_embedded_panel.dart';
import '../panels/rviz2_embedded_panel.dart';
import '../panels/vehicle_data_embedded_panel.dart';
import '../theme/launcher_tokens.dart';

/// App area that hosts either the home panel or an embedded plugin panel,
/// with a soft cross-fade when [selectedAppId] changes.
///
/// Future plugins not yet embedded fall back to [AppPlaceholderPanel].
/// Builds the panel shown for a selected plugin. Defaults to the real
/// embedded plugin panels (OTA, ADSW) with a placeholder fallback, but
/// tests can inject a lightweight builder to skip plugin internals.
typedef AppPanelBuilder = Widget Function(AppManifest app);

class LauncherAppArea extends StatelessWidget {
  const LauncherAppArea({
    super.key,
    required this.apps,
    required this.selectedAppId,
    required this.onAppLaunch,
    this.rosDomainId,
    this.panelBuilder,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;

  /// 런처 Settings 의 **ROS domain** — rviz2 패널의 `ROS_DOMAIN_ID` 프리필로 내려간다
  /// (rviz2 는 ROS2 노드다 — DDS 평면 도메인과는 별개 값일 수 있다).
  final String? rosDomainId;

  /// Optional override for the plugin-panel factory. When null, the
  /// built-in OTA / ADSW / placeholder routing is used.
  final AppPanelBuilder? panelBuilder;

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
      key = Key('app_embedded_${app.id}');
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
    if (panelBuilder != null) {
      return KeyedSubtree(key: key, child: panelBuilder!(app));
    }
    switch (app.id) {
      case 'ota_monitor':
        return OtaEmbeddedPanel(key: key);
      case 'adsw_monitor':
        return AdswEmbeddedPanel(key: key);
      case 'diag_monitor':
        return DiagEmbeddedPanel(key: key);
      case 'lfc_monitor':
        return LfcEmbeddedPanel(key: key);
      case 'rviz2_panel':
        return Rviz2EmbeddedPanel(key: key, domainId: rosDomainId);
      case 'vehicle_data_app':
        return VehicleDataEmbeddedPanel(key: key);
      default:
        return AppPlaceholderPanel(key: key, app: app);
    }
  }
}
