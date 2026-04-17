import 'dart:convert';
import 'dart:io';
import 'app_config.dart';

typedef ConfigFileFinder = Future<File?> Function(List<String> args);

/// F007: surfaced to the UI so a dialog can warn the user that defaults
/// are being used because the on-disk config.json could not be parsed.
/// Set during [loadConfig]; null when the load path succeeded or no file
/// was found at all (silent default).
String? lastConfigLoadWarning;

Future<AppConfig> loadConfig(
  List<String> args, {
  ConfigFileFinder? finder,
}) async {
  lastConfigLoadWarning = null;
  final file = await (finder ?? _findConfigFile)(args);

  if (file == null) {
    stderr.writeln('[config] no config file found; using defaults');
    return AppConfig.defaults();
  }

  try {
    final txt = await file.readAsString();
    final map = json.decode(txt) as Map<String, dynamic>;
    final cfg = AppConfig.fromJson(map);
    stdout.writeln('[config] loaded: ${file.path} (ros=${cfg.rosUrl})');
    return cfg;
  } catch (e) {
    final msg =
        '설정 파일(${file.path}) 파싱에 실패하여 기본값을 사용합니다.\n원인: $e';
    stderr.writeln('[config] $msg');
    lastConfigLoadWarning = msg;
    return AppConfig.defaults();
  }
}

Future<File?> _findConfigFile(List<String> args) async {
  // 1) ENV
  final envPath = Platform.environment['OTA_CONFIG'];
  if (envPath != null && envPath.isNotEmpty) {
    final f = File(envPath);
    if (await f.exists()) return f;
  }

  // 2) 사용자 경로
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    final f = File('$xdg/ota_monitor/config.json');
    if (await f.exists()) return f;
  } else if (home != null && home.isNotEmpty) {
    final f = File('$home/.config/ota_monitor/config.json');
    if (await f.exists()) return f;
  }

  // 3) 시스템 전역
  final sys = File('/etc/ota_monitor/config.json');
  if (await sys.exists()) return sys;

  // 4) 번들 옆
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundleCfg = File('$exeDir/config/config.json');
    if (await bundleCfg.exists()) return bundleCfg;
  } catch (_) {}

  // 5) 안드로이드 보조
  if (Platform.isAndroid) {
    final sd = File('/sdcard/ota_monitor/config.json');
    if (await sd.exists()) return sd;
  }

  return null;
}
