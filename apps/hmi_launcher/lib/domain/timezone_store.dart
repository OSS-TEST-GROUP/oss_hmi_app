import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A selectable timezone with a fixed UTC offset.
///
/// Offsets are **standard-time** (non-DST). Korea (the default) observes no
/// DST, so KST is always exactly +9 and never wrong. The other curated zones
/// use their standard offset — during a DST period a DST-observing zone reads
/// one hour off. That trade-off keeps the launcher dependency-free (no IANA
/// timezone database); a curated automotive HMI does not need sub-hour DST
/// accuracy for a greeting and a wall clock.
class TimezoneOption {
  const TimezoneOption(this.id, this.label, this.offsetMinutes);

  /// Stable identifier persisted to disk (IANA-style name).
  final String id;

  /// Human-readable label shown in Settings.
  final String label;

  /// Fixed offset from UTC in minutes.
  final int offsetMinutes;

  Duration get offset => Duration(minutes: offsetMinutes);
}

/// Curated timezone catalog. Korea first — it is the product default.
// Labels are English to match the launcher's English UI and to render with
// the bundled Latin font (the UI font has no CJK glyphs).
const List<TimezoneOption> kTimezoneCatalog = [
  TimezoneOption('Asia/Seoul', 'Korea (KST, UTC+9)', 9 * 60),
  TimezoneOption('Asia/Tokyo', 'Japan (JST, UTC+9)', 9 * 60),
  TimezoneOption('Asia/Shanghai', 'China (CST, UTC+8)', 8 * 60),
  TimezoneOption('Asia/Kolkata', 'India (IST, UTC+5:30)', 5 * 60 + 30),
  TimezoneOption('Europe/Berlin', 'Central Europe (CET, UTC+1)', 60),
  TimezoneOption('Etc/UTC', 'UTC', 0),
  TimezoneOption('America/New_York', 'US Eastern (EST, UTC-5)', -5 * 60),
  TimezoneOption('America/Los_Angeles', 'US Pacific (PST, UTC-8)', -8 * 60),
];

/// Default timezone id — Korea.
const String kDefaultTimezoneId = 'Asia/Seoul';

TimezoneOption _optionFor(String id) {
  for (final tz in kTimezoneCatalog) {
    if (tz.id == id) return tz;
  }
  return kTimezoneCatalog.first; // default → Korea
}

/// Persists the user-selected display timezone and computes wall-clock time
/// for it, independent of the host/container timezone.
///
/// The launcher computes display time as `DateTime.now().toUtc() + offset`, so
/// the greeting and clock are correct even when the board runs on UTC. Default
/// is Korea (KST). Storage: a JSON file at `<storageDir>/timezone.json`.
///
/// Filesystem access is injected via [readRaw] / [writeRaw] so unit tests run
/// without touching disk — mirrors AppVisibilityStore.
class TimezoneStore extends ChangeNotifier {
  TimezoneStore({
    FutureOr<String?> Function()? readRaw,
    Future<void> Function(String)? writeRaw,
    String? initialId,
  })  : _readRaw = readRaw,
        _writeRaw = writeRaw,
        _selectedId = _optionFor(initialId ?? kDefaultTimezoneId).id;

  final FutureOr<String?> Function()? _readRaw;
  final Future<void> Function(String)? _writeRaw;
  String _selectedId;

  /// Currently selected timezone id (always a catalog entry).
  String get selectedId => _selectedId;

  /// The selected timezone option.
  TimezoneOption get selected => _optionFor(_selectedId);

  /// Wall-clock "now" in the selected timezone. The returned DateTime is in
  /// UTC mode but its fields (hour/minute/…) read as the selected zone's
  /// local time — exactly what greeting/clock formatting needs.
  DateTime now() => DateTime.now().toUtc().add(selected.offset);

  /// Select a timezone by [id]. Unknown ids fall back to Korea. Persists.
  Future<void> select(String id) async {
    final resolved = _optionFor(id).id;
    if (resolved == _selectedId) return;
    _selectedId = resolved;
    notifyListeners();
    await _persist();
  }

  /// Load state from disk. Missing/corrupt → Korea default (tolerant).
  Future<void> load() async {
    final readFn = _readRaw;
    if (readFn == null) return;
    final raw = await readFn();
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final id = decoded['timezone'];
        if (id is String) _selectedId = _optionFor(id).id;
      }
    } catch (_) {
      _selectedId = kDefaultTimezoneId;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final writeFn = _writeRaw;
    if (writeFn == null) return;
    try {
      await writeFn(jsonEncode({'timezone': _selectedId}));
    } catch (_) {
      // Best-effort persistence — failure must not crash the UI.
    }
  }

  // ── Factory: file-backed (production) ────────────────────────────────────
  factory TimezoneStore.file(String storageDir) {
    final path = '$storageDir/timezone.json';
    return TimezoneStore(
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
    );
  }

  // ── Factory: in-memory (tests) ───────────────────────────────────────────
  factory TimezoneStore.inMemory({String? initialId}) {
    String? stored;
    return TimezoneStore(
      readRaw: () => stored,
      writeRaw: (content) async {
        stored = content;
      },
      initialId: initialId,
    );
  }
}
