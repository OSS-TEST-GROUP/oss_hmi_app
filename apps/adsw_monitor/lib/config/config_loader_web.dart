import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'app_config.dart';

/// Web: assets/config/config.json 로드. 없거나 실패하면 defaults.
Future<AppConfig> loadConfig([List<String>? _unused]) async {
  try {
    // 필요에 따라 경로 이름은 바꿔도 됨 (pubspec.yaml에 등록 필수)
    final txt = await rootBundle.loadString('config/config.json');
    final map = json.decode(txt) as Map<String, dynamic>;
    return AppConfig.fromJson(map);
  } catch (_) {
    // 애셋이 없거나 파싱 실패 → 기본값
    return AppConfig.defaults();
  }
}
