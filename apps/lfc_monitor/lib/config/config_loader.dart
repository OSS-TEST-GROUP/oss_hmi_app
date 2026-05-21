import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

/// Try (in order):
///   1. CLI arg `--config <path>`
///   2. env var `LFC_MONITOR_CONFIG`
///   3. `./config/config.json` next to the working dir
///   4. `~/.config/lfc_monitor/config.json`
///   5. `/etc/lfc_monitor/config.json` (system-wide; mirrors ota_monitor)
/// then fall back to AppConfig.defaults().
Future<AppConfig> loadConfig(List<String> args) async {
  final candidates = <String?>[
    _argValue(args, '--config'),
    Platform.environment['LFC_MONITOR_CONFIG'],
    'config/config.json',
    () {
      final home = Platform.environment['HOME'];
      return home == null ? null : '$home/.config/lfc_monitor/config.json';
    }(),
    '/etc/lfc_monitor/config.json',
  ];

  for (final path in candidates) {
    if (path == null) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      stdout.writeln('[lfc_monitor] config: $path');
      return AppConfig.fromJson(json);
    } catch (e) {
      stderr.writeln('[lfc_monitor] failed to parse $path: $e');
    }
  }

  stdout.writeln('[lfc_monitor] config: defaults');
  return AppConfig.defaults();
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
