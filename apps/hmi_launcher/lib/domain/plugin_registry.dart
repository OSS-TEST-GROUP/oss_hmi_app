import 'dart:io';

import 'app_manifest.dart';

/// Outcome of loading a single manifest file. Encapsulates both the happy
/// path and the "parsed but incompatible" / "failed to parse" cases so the
/// UI can render each appropriately.
class RegistryEntry {
  RegistryEntry.ok(this.manifest)
      : compatible = true,
        errorMessage = null;

  RegistryEntry.incompatible(this.manifest, this.errorMessage)
      : compatible = false;

  RegistryEntry.invalid(this.errorMessage)
      : manifest = null,
        compatible = false;

  final AppManifest? manifest;
  final bool compatible;
  final String? errorMessage;

  bool get isValid => manifest != null;
}

/// Snapshot of apps currently exposed by the launcher.
class PluginRegistry {
  PluginRegistry(this.entries);

  final List<RegistryEntry> entries;

  /// Only manifests that parsed successfully AND are compatible with the
  /// current launcher version. These are the apps rendered in the sidebar.
  List<AppManifest> get apps => entries
      .where((e) => e.isValid && e.compatible)
      .map((e) => e.manifest!)
      .toList(growable: false);

  /// Manifests that parsed but require a newer launcher version.
  List<AppManifest> get incompatibleApps => entries
      .where((e) => e.isValid && !e.compatible)
      .map((e) => e.manifest!)
      .toList(growable: false);

  /// Human-readable errors from manifests that failed to parse.
  List<String> get parseErrors => entries
      .where((e) => !e.isValid && e.errorMessage != null)
      .map((e) => e.errorMessage!)
      .toList(growable: false);

  /// Find a registered app by id. Returns null if no such id or incompatible.
  AppManifest? findById(String id) {
    for (final app in apps) {
      if (app.id == id) return app;
    }
    return null;
  }
}

/// Scans an `/apps` directory for `<app>/manifest.json` files and builds a
/// [PluginRegistry].
///
/// Filesystem access is injected via [listEntries] / [readFile] so unit
/// tests can run the scanner against in-memory fixtures without touching
/// `dart:io`.
class PluginRegistryScanner {
  PluginRegistryScanner({
    required this.appsRoot,
    required this.launcherVersion,
    List<String> Function(String dir)? listEntries,
    String? Function(String path)? readFile,
  })  : _listEntries = listEntries ?? _defaultListEntries,
        _readFile = readFile ?? _defaultReadFile;

  /// Absolute or relative path to the `apps/` directory.
  final String appsRoot;

  /// The running launcher's semver string. Manifests whose `min_launcher`
  /// exceeds this value are marked incompatible.
  final String launcherVersion;

  final List<String> Function(String dir) _listEntries;
  final String? Function(String path) _readFile;

  /// Scan [appsRoot] for manifest files and return an immutable registry
  /// snapshot. The scanner is deliberately tolerant: a single broken
  /// manifest never prevents the rest of the registry from loading — the
  /// failure surfaces as a [RegistryEntry.invalid] with an explanation.
  PluginRegistry scan() {
    final subdirs = _listEntries(appsRoot);
    subdirs.sort(); // deterministic order across runs / platforms
    final entries = <RegistryEntry>[];
    for (final dir in subdirs) {
      final manifestPath = '$appsRoot/$dir/manifest.json';
      final raw = _readFile(manifestPath);
      if (raw == null) continue; // no manifest ⇒ not a plugin, skip silently
      try {
        final manifest = AppManifest.parse(raw, sourcePath: manifestPath);
        if (manifest.isIncompatibleWith(launcherVersion)) {
          entries.add(RegistryEntry.incompatible(
            manifest,
            'min_launcher ${manifest.minLauncher} > $launcherVersion',
          ));
        } else {
          entries.add(RegistryEntry.ok(manifest));
        }
      } on ManifestFormatException catch (e) {
        entries.add(RegistryEntry.invalid(e.message));
      }
    }
    return PluginRegistry(List.unmodifiable(entries));
  }

  // ── Defaults backed by dart:io ─────────────────────────────────────────

  static List<String> _defaultListEntries(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) return const [];
    return d
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((e) => e.path.split(Platform.pathSeparator).last)
        .toList();
  }

  static String? _defaultReadFile(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    return f.readAsStringSync();
  }
}
