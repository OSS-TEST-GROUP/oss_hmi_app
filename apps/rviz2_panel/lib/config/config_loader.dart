import 'dart:convert';
import 'dart:io';

import 'app_config.dart';
import 'user_config_store.dart';

/// Config file search order (direct-docker variant):
///   0. **사용자 저장본** `$XDG_CONFIG_HOME/rviz2_panel/config.json` — 화면에서 바꾼 값
///   1. CLI arg `--config <path>`
///   2. env var `RVIZ2_MONITOR_CONFIG`
///   3. `./config/config.json` next to the working dir
///   4. `~/.config/rviz2_panel/config.json`
///   5. `/etc/rviz2_panel/config.json` (system-wide, adsw 가 `:ro` 로 마운트)
/// then fall back to [AppConfig.defaults].
///
/// 0 번이 맨 앞인 이유: 사이트 기본값(5)은 읽기 전용이라 화면에서 고칠 수 없다.
/// 사용자가 저장한 값이 있으면 그것이 이긴다(없으면 종전 순서 그대로).
Future<AppConfig> loadConfig(List<String> args) async {
  final user = await UserConfigStore().load();
  if (user != null) {
    stdout.writeln('[rviz2_panel] config: ${UserConfigStore.defaultPath()} (사용자 저장본)');
    return user;
  }

  final candidates = <String?>[
    _argValue(args, '--config'),
    Platform.environment['RVIZ2_MONITOR_CONFIG'],
    'config/config.json',
    () {
      final home = Platform.environment['HOME'];
      return home == null ? null : '$home/.config/rviz2_panel/config.json';
    }(),
    '/etc/rviz2_panel/config.json',
  ];

  for (final path in candidates) {
    if (path == null) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      stdout.writeln('[rviz2_panel] config: $path');
      return AppConfig.fromJson(json);
    } catch (e) {
      stderr.writeln('[rviz2_panel] failed to parse $path: $e');
    }
  }

  stdout.writeln('[rviz2_panel] config: defaults');
  return AppConfig.defaults();
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
