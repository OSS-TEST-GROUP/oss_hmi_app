import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, AssetBundle;
import 'app_config.dart';

/// F007: web-side equivalent of [lastConfigLoadWarning] (io version).
String? lastConfigLoadWarning;

Future<AppConfig> loadConfig([
  List<String>? unused, // ignored on web
  AssetBundle? bundle, // 테스트용 주입 포인트
]) async {
  lastConfigLoadWarning = null;
  final b = bundle ?? rootBundle;

  try {
    final txt = await b.loadString('config/config.json');
    final map = json.decode(txt) as Map<String, dynamic>;
    return AppConfig.fromJson(map);
  } catch (e) {
    lastConfigLoadWarning =
        'config/config.json 로드 실패로 기본값을 사용합니다.\n원인: $e';
    return AppConfig.defaults();
  }
}