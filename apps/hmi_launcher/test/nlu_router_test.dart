import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';

AppManifest _m(String id, List<String> prompts) => AppManifest(
      id: id,
      name: id,
      icon: '📦',
      version: '1.0.0',
      entry: '$id/main.dart',
      prompts: prompts,
    );

void main() {
  group('NluRouter.resolve', () {
    final apps = [
      _m('ota_monitor', ['OTA 모니터 열어줘', '업데이트 상태 확인']),
      _m('adsw_monitor', ['AD SW 모니터 열어줘', '센서 상태 보여줘']),
    ];
    final router = NluRouter(apps);

    test('matches exact prompt (case-insensitive)', () {
      expect(router.resolve('OTA 모니터 열어줘')?.id, 'ota_monitor');
      expect(router.resolve('ota 모니터 열어줘')?.id, 'ota_monitor');
    });

    test('matches when prompt is a substring of input', () {
      expect(
        router.resolve('지금 OTA 모니터 열어줘 빨리')?.id,
        'ota_monitor',
      );
    });

    test('picks the app with the longest matching prompt', () {
      // Both prompts could match this input; 'OTA 모니터 열어줘' (11 chars)
      // should beat 'AD SW' style shorter phrases if any overlapped.
      final mixedApps = [
        _m('a', ['OTA']),
        _m('b', ['OTA 모니터 열어줘']),
      ];
      expect(NluRouter(mixedApps).resolve('OTA 모니터 열어줘')?.id, 'b');
    });

    test('returns null for empty or whitespace-only input', () {
      expect(router.resolve(''), isNull);
      expect(router.resolve('   '), isNull);
      expect(router.resolve('\t\n'), isNull);
    });

    test('returns null when no prompt matches', () {
      expect(router.resolve('오늘 날씨 어때'), isNull);
    });

    test('tie-break by id lexicographic order when lengths match', () {
      final tied = [
        _m('zzz', ['hello']),
        _m('aaa', ['hello']),
      ];
      expect(NluRouter(tied).resolve('hello')?.id, 'aaa');
    });

    test('falls back only to exact app name or id', () {
      final apps = [
        AppManifest(
          id: 'ota_monitor',
          name: 'OTA Monitor',
          icon: '📦',
          version: '1.0.0',
          entry: 'ota_monitor/main.dart',
          prompts: const ['업데이트 상태 확인'],
        ),
        AppManifest(
          id: 'adsw_monitor',
          name: 'AD SW',
          icon: '📡',
          version: '1.0.0',
          entry: 'adsw_monitor/main.dart',
          prompts: const ['센서 상태 보여줘'],
        ),
      ];
      final r = NluRouter(apps);
      expect(r.resolve('ota monitor')?.id, 'ota_monitor');
      expect(r.resolve('ota_monitor')?.id, 'ota_monitor');
      expect(r.resolve('otamonitor')?.id, 'ota_monitor');
      expect(r.resolve('AD SW')?.id, 'adsw_monitor');
      expect(r.resolve('adsw')?.id, 'adsw_monitor');
      expect(r.resolve('OTA'), isNull);
      expect(r.resolve('ota 모니터 실행해줘'), isNull);
      expect(r.resolve('ad sw 실행해줘'), isNull);
    });

    test('name fallback ignores single-char queries', () {
      final apps = [
        AppManifest(
          id: 'adsw_monitor',
          name: 'AD SW',
          icon: '📡',
          version: '1.0.0',
          entry: 'adsw_monitor/main.dart',
          prompts: const [],
        ),
      ];
      expect(NluRouter(apps).resolve('a'), isNull);
    });
  });
}
