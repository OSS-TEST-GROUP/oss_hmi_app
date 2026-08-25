import 'dart:convert';
import 'dart:io';

import 'app_config.dart';
import 'user_config_store.dart';

/// 설정 탐색 순서 (direct-docker variant):
///
///   1. `$XDG_CONFIG_HOME/rviz2_panel/config.json`      — **사용자 변경분**(화면 저장)
///   2. `$XDG_CONFIG_HOME/rviz2_panel/config_def.json`  — **기기 기본값**(패널이 만든다)
///   3. CLI arg `--config <path>`                        — 개발/단독 실행 오버라이드
///   4. env `RVIZ2_MONITOR_CONFIG`                       — 〃
///   5. `./config/config.json`                           — 단독 실행 시 앱 옆 파일
///   6. [AppConfig.defaults]                             — 코드 기본값
///
/// 2 번 파일이 없으면 3~6 에서 고른 값을 **그 자리에 만들어 둔다**(seed). 그래서 기기에서
/// 기본값을 바꾸고 싶으면 Yocto 이미지를 다시 굽지 않고 그 파일만 고치면 된다.
///
/// 예전에는 사이트 기본값을 `/etc/rviz2_panel/config.json` 으로 마운트했지만, 이미지에
/// 파일·마운트를 넣어야 하고 읽기 전용이라 기기에서 조정할 수 없어 이 방식으로 바꿨다.
Future<AppConfig> loadConfig(List<String> args) async {
  final store = UserConfigStore();

  // 1) 사용자 변경분이 있으면 그것이 이긴다.
  final user = await store.load();
  if (user != null) {
    stdout.writeln('[rviz2_panel] config: ${store.path} (사용자 변경분)');
    return user;
  }

  // 2) 기기 기본값 파일.
  final def = await store.loadDefault();
  if (def != null) {
    stdout.writeln('[rviz2_panel] config: ${store.defPath} (기기 기본값)');
    return def;
  }

  // 3~5) 개발/단독 실행용 경로.
  final candidates = <String?>[
    _argValue(args, '--config'),
    Platform.environment['RVIZ2_MONITOR_CONFIG'],
    'config/config.json',
  ];

  AppConfig base = AppConfig.defaults();
  String origin = 'defaults';
  for (final path in candidates) {
    if (path == null) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      base = AppConfig.fromJson(json);
      origin = path;
      break;
    } catch (e) {
      stderr.writeln('[rviz2_panel] failed to parse $path: $e');
    }
  }

  // 6) 기본값 파일을 만들어 둔다 — 다음 실행부터 2 번에서 읽히고, 기기에서 손댈 수 있다.
  final err = await store.seedDefault(base);
  stdout.writeln(err == null
      ? '[rviz2_panel] config: $origin → ${store.defPath} 생성'
      : '[rviz2_panel] config: $origin (기본값 파일 생성 실패: $err)');
  return base;
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
