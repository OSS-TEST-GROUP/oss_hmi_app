import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:ota_monitor/config/app_config.dart';
import 'package:ota_monitor/logging/app_log.dart';
import 'package:ota_monitor/ros/ros_keeper.dart';

/// F008: rosbridge WebSocket URL validation, persistence, and live re-keep.
///
/// Persists the user-edited URL to the same on-disk location that
/// [config_loader_io._findConfigFile] reads at next startup
/// (`$XDG_CONFIG_HOME/ota_monitor/config.json` or `$HOME/.config/...`),
/// so changes survive an app restart.
typedef RosKeeperFactory = RosKeeper Function(AppConfig cfg);

class SettingsController {
  SettingsController({
    required this.initialConfig,
    required RosKeeper Function() readKeeper,
    required void Function(RosKeeper next) writeKeeper,
    RosKeeperFactory? keeperFactory,
    Future<File> Function()? configFilePathResolver,
  })  : _readKeeper = readKeeper,
        _writeKeeper = writeKeeper,
        _keeperFactory = keeperFactory ?? ((cfg) => RosKeeper(cfg)),
        _configFilePathResolver =
            configFilePathResolver ?? _defaultConfigPath;

  final AppConfig initialConfig;
  final RosKeeper Function() _readKeeper;
  final void Function(RosKeeper next) _writeKeeper;
  final RosKeeperFactory _keeperFactory;
  final Future<File> Function() _configFilePathResolver;

  /// F020 §6: ws:// or wss:// only. Rejects empty, missing host, IPv6
  /// brackets, userinfo, IDN — those are documented limitations.
  static final RegExp urlPattern =
      RegExp(r'^(ws|wss)://[A-Za-z0-9._-]+(:[0-9]{1,5})?(/.*)?$');

  static bool isValidUrl(String input) {
    if (input.isEmpty) return false;
    if (input.length > 2048) return false;
    return urlPattern.hasMatch(input);
  }

  /// Validate + persist + replace RosKeeper in one call.
  /// Returns true on success, false on invalid input. Throws only on I/O
  /// failures from the persistence step.
  Future<bool> applyUrl(String newUrl) async {
    if (!isValidUrl(newUrl)) {
      appLog('[settings] reject invalid url: $newUrl', level: 'warn');
      return false;
    }

    await _persistUrl(newUrl);
    await _replaceKeeper(newUrl);
    return true;
  }

  /// Reset to the URL that was loaded from config.json at startup.
  Future<bool> resetToDefault() => applyUrl(initialConfig.rosUrl.toString());

  Future<void> _persistUrl(String newUrl) async {
    final file = await _configFilePathResolver();

    Map<String, dynamic> existing = {};
    if (await file.exists()) {
      try {
        existing = json.decode(await file.readAsString())
            as Map<String, dynamic>;
      } catch (e) {
        appLog('[settings] existing config unparseable, overwriting: $e',
            level: 'warn');
      }
    } else {
      await file.parent.create(recursive: true);
    }

    final rb = (existing['rosbridge'] as Map?)?.cast<String, dynamic>() ?? {};
    rb['url'] = newUrl;
    existing['rosbridge'] = rb;

    // Atomic write: tmp → rename to avoid half-written file on crash.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(existing),
      flush: true,
    );
    await tmp.rename(file.path);
    appLog('[settings] persisted ${file.path} (url=$newUrl)');
  }

  Future<void> _replaceKeeper(String newUrl) async {
    final newCfg = initialConfig.copyWith(rosUrl: Uri.parse(newUrl));
    final next = _keeperFactory(newCfg);

    final old = _readKeeper();
    _writeKeeper(next);

    // Stop the previous keeper after the global handle has flipped, so
    // any concurrent read resolves to the new keeper rather than a
    // half-stopped one.
    await old.stop();
    await next.start();
  }
}

/// Resolve the writable on-disk config path used by SettingsController and
/// recognised by [config_loader_io._findConfigFile] at next launch.
Future<File> _defaultConfigPath() async {
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  final home = Platform.environment['HOME'];
  final base = (xdg != null && xdg.isNotEmpty)
      ? xdg
      : (home != null && home.isNotEmpty ? '$home/.config' : '/tmp');
  return File('$base/ota_monitor/config.json');
}

/// Test helper: SettingsController writes through this key when an
/// integration test wants to override the config file location without
/// touching `$HOME`.
@visibleForTesting
Future<File> testConfigPathFor(String tmpDir) async =>
    File('$tmpDir/ota_monitor/config.json');
