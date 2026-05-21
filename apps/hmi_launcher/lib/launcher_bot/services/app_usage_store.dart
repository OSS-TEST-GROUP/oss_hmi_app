import 'dart:convert';
import 'dart:io';

class AppUsageStats {
  const AppUsageStats({
    required this.appId,
    required this.openCount,
    required this.lastOpenedAt,
    required this.totalForegroundSeconds,
  });

  final String appId;
  final int openCount;
  final DateTime lastOpenedAt;
  final int totalForegroundSeconds;

  Map<String, dynamic> toJson() => {
        'openCount': openCount,
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
        'totalForegroundSeconds': totalForegroundSeconds,
      };

  static AppUsageStats? fromJson(String appId, Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final openCount = value['openCount'];
    final rawLastOpenedAt = value['lastOpenedAt'];
    final totalForegroundSeconds = value['totalForegroundSeconds'];
    final lastOpenedAt =
        rawLastOpenedAt is String ? DateTime.tryParse(rawLastOpenedAt) : null;
    if (openCount is! int || openCount <= 0 || lastOpenedAt == null) {
      return null;
    }
    return AppUsageStats(
      appId: appId,
      openCount: openCount,
      lastOpenedAt: lastOpenedAt,
      totalForegroundSeconds:
          totalForegroundSeconds is int ? totalForegroundSeconds : 0,
    );
  }
}

class AppUsageStore {
  AppUsageStore({File? file}) : _file = file ?? _defaultFile();

  final File _file;
  final Map<String, AppUsageStats> _stats = {};

  Future<void> load() async {
    _stats.clear();
    if (!await _file.exists()) return;

    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final stats = AppUsageStats.fromJson(entry.key, entry.value);
        if (stats != null) _stats[entry.key] = stats;
      }
    } catch (_) {
      // Corrupt usage data should never block launcher startup.
    }
  }

  Future<void> recordOpen(String appId) async {
    final current = _stats[appId];
    _stats[appId] = AppUsageStats(
      appId: appId,
      openCount: (current?.openCount ?? 0) + 1,
      lastOpenedAt: DateTime.now(),
      totalForegroundSeconds: current?.totalForegroundSeconds ?? 0,
    );
    await _save();
  }

  Future<void> recordForegroundDuration(String appId, Duration duration) async {
    final seconds = duration.inSeconds;
    if (seconds <= 0) return;

    final current = _stats[appId];
    if (current == null) return;

    _stats[appId] = AppUsageStats(
      appId: appId,
      openCount: current.openCount,
      lastOpenedAt: current.lastOpenedAt,
      totalForegroundSeconds: current.totalForegroundSeconds + seconds,
    );
    await _save();
  }

  AppUsageStats? mostUsed(Set<String> validAppIds) {
    AppUsageStats? best;
    for (final stats in _stats.values) {
      if (!validAppIds.contains(stats.appId)) continue;
      if (stats.openCount < 2 && stats.totalForegroundSeconds < 60) continue;
      if (best == null ||
          stats.openCount > best.openCount ||
          (stats.openCount == best.openCount &&
              stats.totalForegroundSeconds > best.totalForegroundSeconds) ||
          (stats.openCount == best.openCount &&
              stats.totalForegroundSeconds == best.totalForegroundSeconds &&
              stats.lastOpenedAt.isAfter(best.lastOpenedAt))) {
        best = stats;
      }
    }
    return best;
  }

  List<AppUsageStats> suggestionCandidates(Set<String> validAppIds) {
    final candidates = _stats.values
        .where((stats) => validAppIds.contains(stats.appId))
        .where(
          (stats) => stats.openCount >= 2 || stats.totalForegroundSeconds >= 60,
        )
        .toList();
    candidates.sort((a, b) {
      final countDiff = b.openCount.compareTo(a.openCount);
      if (countDiff != 0) return countDiff;
      final dwellDiff =
          b.totalForegroundSeconds.compareTo(a.totalForegroundSeconds);
      if (dwellDiff != 0) return dwellDiff;
      return b.lastOpenedAt.compareTo(a.lastOpenedAt);
    });
    return List.unmodifiable(candidates);
  }

  Future<void> _save() async {
    final payload = {
      for (final entry in _stats.entries) entry.key: entry.value.toJson(),
    };
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(payload)}\n');
  }

  static File _defaultFile() {
    final override = Platform.environment['HMI_LAUNCHER_USAGE'];
    if (override != null && override.isNotEmpty) return File(override);

    final xdg = Platform.environment['XDG_CONFIG_HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      return File('$xdg/hmi_launcher/app_usage.json');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return File('$home/.config/hmi_launcher/app_usage.json');
    }

    return File('/var/lib/hmi_launcher/app_usage.json');
  }
}
