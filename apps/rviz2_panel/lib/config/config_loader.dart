import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

/// Config file search order (direct-docker variant):
///   1. CLI arg `--config <path>`
///   2. env var `RVIZ2_MONITOR_CONFIG`
///   3. `./config/config.json` next to the working dir
///   4. `~/.config/rviz2_panel/config.json`
///   5. `/etc/rviz2_panel/config.json` (system-wide)
/// then fall back to [AppConfig.defaults].
Future<AppConfig> loadConfig(List<String> args) async {
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
