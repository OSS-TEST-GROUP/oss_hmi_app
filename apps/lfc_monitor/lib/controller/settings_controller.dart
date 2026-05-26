import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../ros_keeper.dart';

/// F014 / S5-4: rosbridge URL + theme persistence + live RosKeeper swap.
///
/// Mirrors ota_monitor's SettingsController shape so launcher-embedded
/// sessions feel consistent across apps, but stays self-contained — no
/// runtime log capture, no GetX dependency. Persists to the same JSON
/// file that loadConfig() reads at startup so the change survives a
/// restart.
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

  /// ws:// or wss:// only. Rejects empty, missing host, IPv6 brackets,
  /// userinfo, IDN — matches ota_monitor's contract.
  static final RegExp urlPattern =
      RegExp(r'^(ws|wss)://[A-Za-z0-9._-]+(:[0-9]{1,5})?(/.*)?$');

  static bool isValidUrl(String input) {
    if (input.isEmpty) return false;
    if (input.length > 2048) return false;
    return urlPattern.hasMatch(input);
  }

  /// Validate + persist + replace the live RosKeeper.
  /// Returns true on success, false on invalid input.  Throws only on
  /// I/O failures from the persistence step (caller surfaces via UI).
  Future<bool> applyUrl(String newUrl) async {
    final url = newUrl.trim();
    if (!isValidUrl(url)) return false;

    await _persistUrl(url);
    await _replaceKeeper(url);
    return true;
  }

  /// Reset to the URL loaded from config.json at app startup.
  Future<bool> resetToDefault() => applyUrl(initialConfig.rosUrl.toString());

  /// Persist the chosen theme name. The live paletteNotifier is updated
  /// by the caller (UI) for an instant swap; this method only handles
  /// the on-disk record.
  Future<bool> applyTheme(String name) async {
    if (name != 'light' && name != 'dark') return false;
    await _persistTheme(name);
    return true;
  }

  Future<void> _persistTheme(String name) =>
      _writeJsonField((existing) => existing['theme'] = name);

  Future<void> _persistUrl(String newUrl) => _writeJsonField((existing) {
        final rb = (existing['rosbridge'] as Map?)?.cast<String, dynamic>() ?? {};
        rb['url'] = newUrl;
        existing['rosbridge'] = rb;
      });

  /// Shared atomic write — read existing JSON if present, mutate, write
  /// to a tmp file, then rename. Avoids half-written files on crash.
  Future<void> _writeJsonField(
      void Function(Map<String, dynamic> existing) mutate) async {
    final file = await _configFilePathResolver();

    Map<String, dynamic> existing = {};
    if (await file.exists()) {
      try {
        existing = json.decode(await file.readAsString())
            as Map<String, dynamic>;
      } catch (_) {
        // Existing config unparseable — overwrite from scratch.
      }
    } else {
      await file.parent.create(recursive: true);
    }

    mutate(existing);

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(existing),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  Future<void> _replaceKeeper(String newUrl) async {
    final old = _readKeeper();
    final baseCfg = old.cfg;
    final newCfg = baseCfg.copyWith(rosUrl: Uri.parse(newUrl));
    final next = _keeperFactory(newCfg);

    // Flip the global handle FIRST so concurrent readers resolve to the
    // new keeper rather than a half-stopped one. start() awaited last so
    // the UI sees a fully-connecting keeper by the time Apply returns.
    _writeKeeper(next);
    await old.stop();
    await next.start();
  }
}

/// Default config path resolver. Mirrors loadConfig()'s priority so a
/// settings write lands at the same file the next startup reads:
///   1. $LFC_MONITOR_CONFIG (env override)
///   2. $XDG_CONFIG_HOME/lfc_monitor/config.json
///   3. $HOME/.config/lfc_monitor/config.json
///   4. /tmp fallback
Future<File> _defaultConfigPath() async {
  final envPath = Platform.environment['LFC_MONITOR_CONFIG'];
  if (envPath != null && envPath.isNotEmpty) {
    return File(envPath);
  }
  final xdg = Platform.environment['XDG_CONFIG_HOME'];
  if (xdg != null && xdg.isNotEmpty) {
    return File('$xdg/lfc_monitor/config.json');
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return File('$home/.config/lfc_monitor/config.json');
  }
  return File('/tmp/lfc_monitor/config.json');
}
