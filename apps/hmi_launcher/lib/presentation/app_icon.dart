import 'package:flutter/material.dart';

import '../domain/app_manifest.dart';

abstract final class LauncherAppIcons {
  static const settings = Icons.settings_outlined;

  static IconData forApp(AppManifest app) => forId(app.id);

  static IconData forId(String? appId) {
    switch (appId) {
      case 'ota_monitor':
        return Icons.system_update_alt;
      case 'adsw_monitor':
        return Icons.sensors_outlined;
      case 'lfc_monitor':
        return Icons.account_tree_outlined;
      case settingsAppId:
        return settings;
      default:
        return Icons.apps_outlined;
    }
  }

  static const settingsAppId = '__settings__';
}
