import 'dart:convert';
import 'dart:io';
import 'app_config.dart';

/// 우선순위:
/// 1) CLI: --config=/path/file.json
/// 2) ENV: ADSW_CONFIG
/// 3) 사용자: $XDG_CONFIG_HOME/adsw_monitor/config.json 또는 ~/.config/adsw_monitor/config.json
/// 4) 시스템: /etc/adsw_monitor/config.json
/// 5) 번들 옆: <bundle>/config/config.json
/// 없으면 기본값.
Future<AppConfig> loadConfig(List<String> args) async {
  final file = await _findConfigFile(args);
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
    stderr.writeln('[config] failed to parse ${file.path}: $e (use defaults)');
    return AppConfig.defaults();
  }
}

Future<File?> _findConfigFile(List<String> args) async {
  // 1) CLI arg
  final arg = args.firstWhere(
    (a) => a.startsWith('--config='),
    orElse: () => '',
  );
  if (arg.isNotEmpty) {
    final p = arg.split('=')[1];
    final f = File(p);
    if (await f.exists()) return f;
  }

  // 2) ENV
  final envPath = Platform.environment['ADSW_CONFIG'];
  if (envPath != null && envPath.isNotEmpty) {
    final f = File(envPath);
    if (await f.exists()) return f;
  }

  // 3) 사용자 경로
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    final f = File('$xdg/adsw_monitor/config.json');
    if (await f.exists()) return f;
  } else if (home != null && home.isNotEmpty) {
    final f = File('$home/.config/adsw_monitor/config.json');
    if (await f.exists()) return f;
  }

  // 4) 시스템 전역
  final sys = File('/etc/adsw_monitor/config.json');
  if (await sys.exists()) return sys;

  // 5) 번들 옆
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundleCfg = File('$exeDir/config/config.json');
    if (await bundleCfg.exists()) return bundleCfg;
  } catch (_) {}

  return null;
}