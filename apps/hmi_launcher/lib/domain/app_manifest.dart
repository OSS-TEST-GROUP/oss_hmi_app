import 'dart:convert';

/// Strongly-typed representation of an `apps/<app>/manifest.json` file.
///
/// Shape is defined by the AGL Launcher v4 plan (page 3). Required fields
/// are [id], [name], [icon], [version], [entry]; everything else falls back
/// to sensible defaults so older manifests still load.
///
/// Use [AppManifest.parse] to build an instance from a raw JSON string; it
/// throws [ManifestFormatException] with a specific message when a required
/// field is missing or malformed.
class AppManifest {
  AppManifest({
    required this.id,
    required this.name,
    required this.icon,
    required this.version,
    required this.entry,
    this.category = 'misc',
    this.color = '#64748B',
    this.prompts = const [],
    this.permissions = const [],
    this.minLauncher = '0.0.0',
  });

  /// Stable id used as the directory name under /apps and as the routing key.
  final String id;

  /// Human-readable title rendered in the sidebar and app cards.
  final String name;

  /// Icon glyph (emoji) or asset path rendered in sidebar / card.
  final String icon;

  /// Semantic version of the app (semver string).
  final String version;

  /// Entry-point path relative to the app package root,
  /// e.g. `ota_monitor/main.dart`.
  final String entry;

  /// Category tag used for sidebar grouping and sort order.
  /// Known values in v4: `monitoring`, `visualization`, `assistant`, `misc`.
  final String category;

  /// Hex color (#RRGGBB) rendered as the accent on sidebar items and cards.
  final String color;

  /// User-facing phrases that match this app in the rule-based NLU router.
  final List<String> prompts;

  /// AGL platform permissions the app requires (e.g. `vss`, `can_bus`).
  final List<String> permissions;

  /// Minimum launcher version required. Compared as semver.
  final String minLauncher;

  /// Parse a raw JSON string into an [AppManifest].
  ///
  /// Throws [ManifestFormatException] if the JSON is malformed or a required
  /// field is missing.
  factory AppManifest.parse(String source, {String? sourcePath}) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ManifestFormatException(
        'invalid JSON${sourcePath == null ? '' : ' at $sourcePath'}: ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ManifestFormatException(
        'manifest must be a JSON object${sourcePath == null ? '' : ' ($sourcePath)'}',
      );
    }
    return AppManifest.fromJson(decoded, sourcePath: sourcePath);
  }

  /// Build an [AppManifest] from a decoded JSON map.
  factory AppManifest.fromJson(
    Map<String, dynamic> json, {
    String? sourcePath,
  }) {
    String requireString(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) {
        throw ManifestFormatException(
          "missing or invalid required field '$key'"
          "${sourcePath == null ? '' : ' ($sourcePath)'}",
        );
      }
      return v;
    }

    List<String> asStringList(String key) {
      final v = json[key];
      if (v == null) return const [];
      if (v is! List) {
        throw ManifestFormatException(
          "field '$key' must be a list${sourcePath == null ? '' : ' ($sourcePath)'}",
        );
      }
      return v.whereType<String>().toList(growable: false);
    }

    return AppManifest(
      id: requireString('id'),
      name: requireString('name'),
      icon: requireString('icon'),
      version: requireString('version'),
      entry: requireString('entry'),
      category: (json['category'] as String?) ?? 'misc',
      color: (json['color'] as String?) ?? '#64748B',
      prompts: asStringList('prompts'),
      permissions: asStringList('permissions'),
      minLauncher: (json['min_launcher'] as String?) ?? '0.0.0',
    );
  }

  /// Compare [minLauncher] against the caller's launcher version.
  ///
  /// Returns true when the manifest declares a minimum that is higher than
  /// the current launcher — the app should be rendered as "incompatible".
  bool isIncompatibleWith(String launcherVersion) {
    return _compareSemver(minLauncher, launcherVersion) > 0;
  }

  @override
  String toString() => 'AppManifest($id v$version)';
}

/// Thrown when a manifest cannot be parsed or is missing required fields.
class ManifestFormatException implements Exception {
  ManifestFormatException(this.message);
  final String message;
  @override
  String toString() => 'ManifestFormatException: $message';
}

/// Semver comparator. Only supports major.minor.patch; pre-release tags are
/// stripped so `1.2.3-rc1` compares equal to `1.2.3`. Returns a negative,
/// zero, or positive integer following Dart's Comparator convention.
int _compareSemver(String a, String b) {
  List<int> parts(String v) {
    final clean = v.split(RegExp('[-+]')).first;
    final segments = clean.split('.');
    return List<int>.generate(
      3,
      (i) => int.tryParse(segments.length > i ? segments[i] : '0') ?? 0,
    );
  }

  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final diff = pa[i] - pb[i];
    if (diff != 0) return diff;
  }
  return 0;
}
