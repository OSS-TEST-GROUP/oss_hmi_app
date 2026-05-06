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
  ///
  /// Input is trimmed before validation so leading/trailing whitespace
  /// from copy-paste doesn't reject otherwise-valid URLs (CONSIDER #1).
  Future<bool> applyUrl(String newUrl) async {
    final url = newUrl.trim();
    if (!isValidUrl(url)) {
      appLog('[settings] reject invalid url: $url', level: 'warn');
      return false;
    }

    await _persistUrl(url);
    await _replaceKeeper(url);
    return true;
  }

  /// Reset to the URL that was loaded from config.json at startup.
  Future<bool> resetToDefault() => applyUrl(initialConfig.rosUrl.toString());

  /// Persist the chosen UI theme name ('light' or 'dark') to config.json
  /// using the same priority chain as URL persistence. The live
  /// `paletteNotifier` is updated by the caller (UI) so the swap is
  /// instant; this method only handles the on-disk record.
  Future<bool> applyTheme(String name) async {
    if (name != 'light' && name != 'dark') {
      appLog('[settings] reject invalid theme: $name', level: 'warn');
      return false;
    }
    await _persistTheme(name);
    return true;
  }

  Future<void> _persistTheme(String name) async {
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

    existing['theme'] = name;

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(existing),
      flush: true,
    );
    await tmp.rename(file.path);
    appLog('[settings] persisted theme=$name to ${file.path}');
  }

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
    // SHOULD #4: base the next config on the *current* keeper's config,
    // not the startup-time initialConfig. This preserves any other live
    // settings (status topic, intervals, historySize, ...) that a future
    // feature may add, avoiding silent reset of unrelated fields.
    final old = _readKeeper();
    final baseCfg = old.cfg;
    final newCfg = baseCfg.copyWith(rosUrl: Uri.parse(newUrl));
    final next = _keeperFactory(newCfg);

    _writeKeeper(next);

    // Stop the previous keeper after the global handle has flipped, so
    // any concurrent read resolves to the new keeper rather than a
    // half-stopped one. next.start() is awaited last so the UI sees a
    // fully-connecting keeper by the time Apply returns.
    await old.stop();
    await next.start();
  }
}

/// Resolve the writable on-disk config path. The order MUST mirror
/// [config_loader_io._findConfigFile] so that whatever is loaded at the
/// next launch is the same file that SettingsController writes today.
///
/// Specifically, if the user launched the app with `OTA_CONFIG=/path/x.json`,
/// startup loads that file — so persistence MUST also write to that file,
/// otherwise the next launch silently reverts to OTA_CONFIG's value.
/// (Reviewer MUST #1 against revision 0.)
Future<File> _defaultConfigPath() async {
  // 1) ENV override — has the highest precedence at startup, so we MUST
  //    write here when set.
  final envPath = Platform.environment['OTA_CONFIG'];
  if (envPath != null && envPath.isNotEmpty) {
    return File(envPath);
  }

  // 2) XDG_CONFIG_HOME or HOME/.config — config_loader's user-scope path.
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    return File('$xdg/ota_monitor/config.json');
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return File('$home/.config/ota_monitor/config.json');
  }

  // 3) Last-resort: ephemeral. Persistence is best-effort here; the user
  //    should set HOME or OTA_CONFIG for stable storage.
  return File('/tmp/ota_monitor/config.json');
}

/// Test helper: SettingsController writes through this key when an
/// integration test wants to override the config file location without
/// touching `$HOME`.
@visibleForTesting
Future<File> testConfigPathFor(String tmpDir) async =>
    File('$tmpDir/ota_monitor/config.json');
