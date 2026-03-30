import 'dart:convert';
import 'dart:io';
import 'app_config.dart';

typedef ConfigFileFinder = Future<File?> Function(List<String> args);

/// 우선순위:
///   1. CLI --domain=N
///   2. 환경변수 OTA_DDS_DOMAIN=N
///   3. 설정 파일 (dds.domain_id)
///   4. 기본값 0
Future<AppConfig> loadConfig(
  List<String> args, {
  ConfigFileFinder? finder,
}) async {
  // 설정 파일에서 베이스 설정 로드
  AppConfig cfg = AppConfig.defaults();

  final file = await (finder ?? _findConfigFile)(args);
  if (file != null) {
    try {
      final txt = await file.readAsString();
      final map = json.decode(txt) as Map<String, dynamic>;
      cfg = AppConfig.fromJson(map);
      stdout.writeln('[config] loaded: ${file.path} (dds_domain=${cfg.ddsDomainId})');
    } catch (e) {
      stderr.writeln('[config] failed to parse ${file.path}: $e (use defaults)');
    }
  } else {
    stderr.writeln('[config] no config file found; using defaults');
  }

  // 환경변수 OTA_DDS_DOMAIN 적용
  final envDomain = Platform.environment['OTA_DDS_DOMAIN'];
  if (envDomain != null && envDomain.isNotEmpty) {
    final v = int.tryParse(envDomain);
    if (v != null) {
      cfg = AppConfig(ddsDomainId: v);
      stdout.writeln('[config] OTA_DDS_DOMAIN=$v');
    }
  }

  // CLI --domain=N 적용 (최우선)
  final domainArg = args.firstWhere(
    (a) => a.startsWith('--domain='),
    orElse: () => '',
  );
  if (domainArg.isNotEmpty) {
    final v = int.tryParse(domainArg.split('=')[1]);
    if (v != null) {
      cfg = AppConfig(ddsDomainId: v);
      stdout.writeln('[config] --domain=$v (CLI override)');
    }
  }

  stdout.writeln('[config] DDS domain: ${cfg.ddsDomainId}');
  return cfg;
}

Future<File?> _findConfigFile(List<String> args) async {
  // 1) CLI --config=<path>
  final configArg = args.firstWhere(
    (a) => a.startsWith('--config='),
    orElse: () => '',
  );
  if (configArg.isNotEmpty) {
    final f = File(configArg.split('=')[1]);
    if (await f.exists()) return f;
  }

  // 2) ENV OTA_CONFIG
  final envPath = Platform.environment['OTA_CONFIG'];
  if (envPath != null && envPath.isNotEmpty) {
    final f = File(envPath);
    if (await f.exists()) return f;
  }

  // 3) 사용자 경로
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    final f = File('$xdg/ota_monitor/config.json');
    if (await f.exists()) return f;
  } else if (home != null && home.isNotEmpty) {
    final f = File('$home/.config/ota_monitor/config.json');
    if (await f.exists()) return f;
  }

  // 4) 시스템 전역
  final sys = File('/etc/ota_monitor/config.json');
  if (await sys.exists()) return sys;

  // 5) 번들 옆
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundleCfg = File('$exeDir/config/config.json');
    if (await bundleCfg.exists()) return bundleCfg;
  } catch (_) {}

  // 6) 안드로이드 보조
  if (Platform.isAndroid) {
    final sd = File('/sdcard/ota_monitor/config.json');
    if (await sd.exists()) return sd;
  }

  return null;
}
