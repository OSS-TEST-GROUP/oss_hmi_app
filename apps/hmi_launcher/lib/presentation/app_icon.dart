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
      // diag_monitor 는 adsw_monitor 에서 분리된 미들웨어 진단 앱.
      // adsw 의 sensors_outlined(전파)와 형태가 구분되도록 심박 모니터 아이콘.
      case 'diag_monitor':
        return Icons.monitor_heart_outlined;
      case 'lfc_monitor':
        return Icons.account_tree_outlined;
      // rviz2_panel 은 케이스가 없어 기본값 Icons.apps_outlined 로 떨어졌고, 그것이
      // 사이드바/우상단의 "Manage Apps"(앱 그리드) 아이콘과 같아 구분이 되지 않았다.
      // rviz2 는 차량 주변 인지·궤적을 그리는 자율주행 시각화 도구다 → radar.
      // (adsw_monitor 의 sensors_outlined(전파 아이콘)와도 형태가 구분된다)
      case 'rviz2_panel':
        return Icons.radar;
      case 'vehicle_data_app':
        return Icons.directions_car_outlined;
      case settingsAppId:
        return settings;
      default:
        return Icons.apps_outlined;
    }
  }

  static const settingsAppId = '__settings__';
}
