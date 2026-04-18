// Filesystem-backed tests that verify the default scanner actually finds
// the real apps/<app>/manifest.json files committed next to the launcher.
// These tests run `flutter test` from apps/hmi_launcher/ so the launcher's
// `apps/` tree lives at `..` relative to the working directory.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/plugin_registry.dart';

const String _appsRoot = '..'; // apps/hmi_launcher/.. == apps/

void main() {
  group('PluginRegistryScanner against real apps/ tree', () {
    test('discovers ota_monitor manifest when present', () {
      final manifestPath = '$_appsRoot/ota_monitor/manifest.json';
      if (!File(manifestPath).existsSync()) {
        markTestSkipped('$manifestPath not present in this checkout.');
        return;
      }

      final registry = PluginRegistryScanner(
        appsRoot: _appsRoot,
        launcherVersion: '4.0.0',
      ).scan();

      final ota = registry.findById('ota_monitor');
      expect(ota, isNotNull,
          reason: 'ota_monitor/manifest.json must be discovered by scanner');
      expect(ota!.name, 'OTA Monitor');
      expect(ota.prompts, contains('OTA 모니터 열어줘'));
      expect(ota.minLauncher, '4.0.0');
    });

    test('scanner is idempotent and tolerates missing manifests', () {
      // Running twice must yield the same app ids.
      final scanner = PluginRegistryScanner(
        appsRoot: _appsRoot,
        launcherVersion: '4.0.0',
      );
      final ids1 = scanner.scan().apps.map((a) => a.id).toSet();
      final ids2 = scanner.scan().apps.map((a) => a.id).toSet();
      expect(ids1, ids2);
      // Subdirectories under apps/ that lack a manifest.json must be
      // silently skipped — docker/tools/output all live there.
      expect(registryShouldNotIncludeNonPlugin(ids1), isTrue);
    });
  });
}

/// A plugin directory is one with a manifest.json. Known non-plugin
/// subdirectories under apps/ (docker, tools, output) must not appear in
/// the registry regardless of whether they exist in the checkout.
bool registryShouldNotIncludeNonPlugin(Set<String> ids) {
  for (final notPlugin in const ['docker', 'tools', 'output']) {
    if (ids.contains(notPlugin)) return false;
  }
  return true;
}
