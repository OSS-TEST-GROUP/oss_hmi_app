import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, AssetBundle;
import 'app_config.dart';

Future<AppConfig> loadConfig([
  List<String>? _unused,
  AssetBundle? bundle, // 테스트용 주입 포인트
]) async {
  final b = bundle ?? rootBundle;

  try {
    final txt = await b.loadString('config/config.json');
    final map = json.decode(txt) as Map<String, dynamic>;
    return AppConfig.fromJson(map);
  } catch (_) {
    // 애셋이 없거나 파싱 실패 -> 기본값
    return AppConfig.defaults();
  }
}