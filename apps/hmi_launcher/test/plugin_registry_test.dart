import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';

const _otaManifest = '''
{
  "id": "ota_monitor",
  "name": "OTA Monitor",
  "icon": "📦",
  "version": "1.0.0",
  "category": "monitoring",
  "color": "#FCD34D",
  "prompts": ["OTA 모니터 열어줘", "업데이트 상태 확인"],
  "entry": "ota_monitor/main.dart",
  "permissions": ["vss", "can_bus"],
  "min_launcher": "4.0.0"
}
''';

const _adswManifest = '''
{
  "id": "adsw_monitor",
  "name": "AD SW",
  "icon": "📡",
  "version": "1.0.0",
  "category": "monitoring",
  "color": "#7FE5A1",
  "prompts": ["AD SW 모니터 열어줘"],
  "entry": "adsw_monitor/main.dart"
}
''';

void main() {
  group('AppManifest.parse', () {
    test('parses all fields including optional defaults', () {
      final m = AppManifest.parse(_otaManifest);
      expect(m.id, 'ota_monitor');
      expect(m.name, 'OTA Monitor');
      expect(m.icon, '📦');
      expect(m.version, '1.0.0');
      expect(m.entry, 'ota_monitor/main.dart');
      expect(m.category, 'monitoring');
      expect(m.color, '#FCD34D');
      expect(m.prompts.length, 2);
      expect(m.permissions, ['vss', 'can_bus']);
      expect(m.minLauncher, '4.0.0');
    });

    test('falls back to defaults for optional fields', () {
      final m = AppManifest.parse(_adswManifest);
      expect(m.prompts.length, 1);
      expect(m.permissions, isEmpty);
      expect(m.minLauncher, '0.0.0');
      expect(m.color, '#7FE5A1');
    });

    test('throws on missing required field', () {
      expect(
        () => AppManifest.parse('{"id":"x","name":"n","icon":"i","version":"1"}'),
        throwsA(isA<ManifestFormatException>()),
      );
    });

    test('throws on invalid JSON', () {
      expect(
        () => AppManifest.parse('{ not valid json'),
        throwsA(isA<ManifestFormatException>()),
      );
    });
  });

  group('AppManifest.isIncompatibleWith', () {
    test('returns true when min_launcher is higher than running version', () {
      final m = AppManifest.parse(_otaManifest); // min_launcher 4.0.0
      expect(m.isIncompatibleWith('3.9.9'), isTrue);
    });

    test('returns false when running version matches or exceeds', () {
      final m = AppManifest.parse(_otaManifest);
      expect(m.isIncompatibleWith('4.0.0'), isFalse);
      expect(m.isIncompatibleWith('5.0.0'), isFalse);
    });

    test('treats pre-release suffixes as the base version', () {
      final m = AppManifest.parse(_otaManifest);
      // 4.0.0-rc1 should compare equal to 4.0.0
      expect(m.isIncompatibleWith('4.0.0-rc1'), isFalse);
    });
  });

  group('PluginRegistryScanner', () {
    PluginRegistry scanFixture(Map<String, String> fs,
        {String launcherVersion = '4.0.0'}) {
      final subdirs =
          fs.keys.map((p) => p.split('/').first).toSet().toList()..sort();
      final scanner = PluginRegistryScanner(
        appsRoot: 'apps',
        launcherVersion: launcherVersion,
        listEntries: (dir) =>
            dir == 'apps' ? List.of(subdirs) : const <String>[],
        readFile: (path) {
          // fs keys are relative to 'apps/', so strip the prefix
          const prefix = 'apps/';
          if (!path.startsWith(prefix)) return null;
          return fs[path.substring(prefix.length)];
        },
      );
      return scanner.scan();
    }

    test('discovers valid manifests and skips subdirs without one', () {
      final reg = scanFixture({
        'ota_monitor/manifest.json': _otaManifest,
        'adsw_monitor/manifest.json': _adswManifest,
        'no_manifest/README.md': 'not a plugin',
      });
      expect(reg.apps.length, 2);
      expect(reg.parseErrors, isEmpty);
      expect(reg.findById('ota_monitor')?.name, 'OTA Monitor');
      expect(reg.findById('adsw_monitor')?.icon, '📡');
    });

    test('marks manifests with higher min_launcher as incompatible', () {
      final reg = scanFixture(
        {'ota_monitor/manifest.json': _otaManifest},
        launcherVersion: '3.0.0',
      );
      expect(reg.apps, isEmpty);
      expect(reg.incompatibleApps.length, 1);
      expect(reg.incompatibleApps.first.id, 'ota_monitor');
    });

    test('records parse errors for malformed manifests but continues scanning',
        () {
      final reg = scanFixture({
        'broken/manifest.json': '{ invalid',
        'adsw_monitor/manifest.json': _adswManifest,
      });
      // broken ⇒ parseErrors, adsw ⇒ apps
      expect(reg.apps.length, 1);
      expect(reg.apps.first.id, 'adsw_monitor');
      expect(reg.parseErrors.length, 1);
      expect(reg.parseErrors.first, contains('invalid JSON'));
    });

    test('findById returns null for unknown id', () {
      final reg = scanFixture({'ota_monitor/manifest.json': _otaManifest});
      expect(reg.findById('does_not_exist'), isNull);
    });

    test('handles empty apps root gracefully', () {
      final reg = scanFixture(const {});
      expect(reg.entries, isEmpty);
      expect(reg.apps, isEmpty);
    });
  });
}
