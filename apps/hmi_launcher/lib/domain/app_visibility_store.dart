import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Persists the set of app IDs that have been explicitly disabled by the user.
///
/// Default policy: every discovered app is **enabled** unless it is listed in
/// [kDefaultDisabled] (apps that ship hidden until the user opts in — currently
/// OTA Monitor) or the user has explicitly disabled it.  Only the "disabled"
/// set is stored on disk; once a state file exists it fully replaces the
/// defaults, so a user enabling a default-disabled app sticks across restarts,
/// and newly installed apps appear automatically without any migration.
///
/// Storage: a JSON file at `<storageDir>/app_visibility.json`.
///
/// Filesystem access is injected via the [readRaw] / [writeRaw] callbacks so
/// unit tests can run the store without touching the real disk.
class AppVisibilityStore extends ChangeNotifier {
  AppVisibilityStore({
    FutureOr<String?> Function()? readRaw,
    Future<void> Function(String)? writeRaw,
    Set<String>? initialDisabled,
  })  : _readRaw = readRaw,
        _writeRaw = writeRaw,
        _disabled = initialDisabled ?? <String>{},
        _initialDisabled = Set<String>.unmodifiable(initialDisabled ?? const <String>{});

  /// Apps hidden by default on a fresh install (no state file yet).
  /// Applied by the production [AppVisibilityStore.file] factory only, so
  /// in-memory test stores keep the historical all-enabled default.
  static const Set<String> kDefaultDisabled = {'ota_monitor'};

  final FutureOr<String?> Function()? _readRaw;
  final Future<void> Function(String)? _writeRaw;
  Set<String> _disabled;

  /// Snapshot of the constructor-time disabled set — the fallback when the
  /// persisted file is corrupt (resetting to `{}` would silently re-enable
  /// default-disabled apps).
  final Set<String> _initialDisabled;

  /// Returns true when the app identified by [id] is enabled (visible).
  bool isEnabled(String id) => !_disabled.contains(id);

  /// Enable (show) the app with [id].  Persists immediately.
  Future<void> enable(String id) async {
    if (!_disabled.contains(id)) return;
    _disabled = Set<String>.from(_disabled)..remove(id);
    notifyListeners();
    await _persist();
  }

  /// Disable (hide) the app with [id].  Persists immediately.
  Future<void> disable(String id) async {
    if (_disabled.contains(id)) return;
    _disabled = Set<String>.from(_disabled)..add(id);
    notifyListeners();
    await _persist();
  }

  /// Toggle visibility of [id].  Persists immediately.
  Future<void> toggle(String id) async {
    if (isEnabled(id)) {
      await disable(id);
    } else {
      await enable(id);
    }
  }

  /// Load state from disk.  Call once after construction.
  ///
  /// Missing file → empty disabled set (all apps enabled).  Corrupt JSON →
  /// treated as empty (tolerant, no crash).
  Future<void> load() async {
    final readFn = _readRaw;
    if (readFn == null) return;
    final raw = await readFn();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final list = decoded['disabled'];
        if (list is List) {
          _disabled = list.whereType<String>().toSet();
        }
      }
    } catch (_) {
      // Corrupt file → reset to the constructor-time defaults (NOT `{}`,
      // which would re-enable default-disabled apps like OTA Monitor).
      _disabled = Set<String>.from(_initialDisabled);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final writeFn = _writeRaw;
    if (writeFn == null) return;
    try {
      await writeFn(
        jsonEncode({'disabled': _disabled.toList()..sort()}),
      );
    } catch (_) {
      // Best-effort persistence — failure must not crash the UI.
    }
  }

  // ── Factory: file-backed (production) ────────────────────────────────────

  /// Creates a file-backed [AppVisibilityStore] writing to [storageDir].
  ///
  /// The file is created on first write.  Missing file → [kDefaultDisabled]
  /// apps hidden, everything else enabled.  An existing file fully replaces
  /// the defaults (user choices win).
  factory AppVisibilityStore.file(String storageDir) {
    final path = '$storageDir/app_visibility.json';
    return AppVisibilityStore(
      readRaw: () async {
        final f = File(path);
        if (!await f.exists()) return null;
        return f.readAsString();
      },
      writeRaw: (content) async {
        final f = File(path);
        await f.parent.create(recursive: true);
        await f.writeAsString(content);
      },
      initialDisabled: Set<String>.from(kDefaultDisabled),
    );
  }

  // ── Factory: in-memory (tests) ────────────────────────────────────────────

  /// Creates an in-memory [AppVisibilityStore] for unit tests.
  ///
  /// The store behaves exactly like the file-backed version (load / persist
  /// cycle works) but never touches disk.
  factory AppVisibilityStore.inMemory({Set<String>? initialDisabled}) {
    String? stored;
    return AppVisibilityStore(
      readRaw: () => stored,
      writeRaw: (content) async {
        stored = content;
      },
      initialDisabled: initialDisabled,
    );
  }
}
