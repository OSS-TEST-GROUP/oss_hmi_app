// QA(docs/qa): FallbackLauncherBotAiService — gRPC 없이 동작하는 폴백 AI 서비스.
// generate / suggestAppToOpen / resolveIntent / transcribeAudio / dispose 분기 검증.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';

AppManifest _m(String id, {String? name}) => AppManifest(
      id: id, name: name ?? id, icon: '📦', version: '1.0.0',
      entry: '$id/main.dart', prompts: const [],
    );

AppUsageStats _u(String id, int count, DateTime last) => AppUsageStats(
      appId: id, openCount: count, lastOpenedAt: last, totalForegroundSeconds: 0,
    );

void main() {
  const svc = FallbackLauncherBotAiService();

  test('generate: contexts 비어있으면 Launcher 라벨', () async {
    final out = await svc.generate(prompt: '안녕', contexts: const []);
    expect(out, contains('안녕'));
    expect(out, contains('Launcher'));
  });

  test('generate: 첫 context 라벨 사용', () async {
    final out = await svc.generate(prompt: 'hi', contexts: const ['OTA']);
    expect(out, contains('hi'));
    expect(out, contains('OTA'));
  });

  test('resolveIntent 는 항상 null', () async {
    final r = await svc.resolveIntent(
        prompt: 'x', apps: const [], currentContext: 'Launcher');
    expect(r, isNull);
  });

  test('suggestAppToOpen: Launcher 외 컨텍스트면 null', () async {
    final r = await svc.suggestAppToOpen(
      apps: [_m('ota_monitor')],
      usages: [_u('ota_monitor', 5, DateTime(2026, 1, 1))],
      currentContext: 'OTA Monitor',
    );
    expect(r, isNull);
  });

  test('suggestAppToOpen: usages 비어있으면 null', () async {
    final r = await svc.suggestAppToOpen(
      apps: [_m('ota_monitor')], usages: const [], currentContext: 'Launcher');
    expect(r, isNull);
  });

  test('suggestAppToOpen: openCount 최다 앱 추천', () async {
    final r = await svc.suggestAppToOpen(
      apps: [_m('ota_monitor', name: 'OTA'), _m('adsw_monitor', name: 'ADSW')],
      usages: [
        _u('ota_monitor', 3, DateTime(2026, 1, 1)),
        _u('adsw_monitor', 7, DateTime(2026, 1, 2)),
      ],
      currentContext: 'Launcher',
    );
    expect(r, isNotNull);
    expect(r!.appId, 'adsw_monitor');
    expect(r.message, contains('ADSW'));
  });

  test('suggestAppToOpen: 동점이면 최근 사용 우선', () async {
    final r = await svc.suggestAppToOpen(
      apps: [_m('a'), _m('b')],
      usages: [
        _u('a', 4, DateTime(2026, 1, 1)),
        _u('b', 4, DateTime(2026, 6, 1)),
      ],
      currentContext: 'Launcher',
    );
    expect(r!.appId, 'b');
  });

  test('suggestAppToOpen: best 앱이 apps 목록에 없으면 null', () async {
    final r = await svc.suggestAppToOpen(
      apps: [_m('other')],
      usages: [_u('ghost', 9, DateTime(2026, 1, 1))],
      currentContext: 'Launcher',
    );
    expect(r, isNull);
  });

  test('transcribeAudio 는 미지원(throw)', () {
    expect(
      () => svc.transcribeAudio(
          pcm: Float32List(4), sampleRate: 16000, channels: 1),
      throwsA(anything),
    );
  });

  test('dispose 는 예외 없이 no-op', () {
    expect(svc.dispose, returnsNormally);
  });
}
