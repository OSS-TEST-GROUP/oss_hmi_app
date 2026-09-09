// QA(docs/qa): LauncherBotController 미커버 경로 (제안/수락/거절/로컬명령/컨텍스트).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_controller.dart';

class _FakeAi implements LauncherBotAiService {
  const _FakeAi();
  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async =>
      'ans';
  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async {
    if (apps.isEmpty) return null;
    return LauncherBotAiAppSuggestion(
      appId: apps.first.id,
      message: '${apps.first.name} 실행할까요?',
    );
  }

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) async =>
      '';

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async =>
      null;

  @override
  void dispose() {}
}

AppManifest _m(String id) => AppManifest(
      id: id, name: id, icon: '📦', version: '1.0.0',
      entry: '$id/main.dart', prompts: const [],
    );

void main() {
  LauncherBotController ctrl({
    List<AppManifest>? apps,
    ValueChanged<AppManifest>? onOpen,
  }) =>
      LauncherBotController(
        nluRouter: NluRouter(apps ?? [_m('ota_monitor')]),
        aiService: const _FakeAi(),
        onOpenApp: onOpen ?? (_) {},
        onCloseApp: () => null,
        onOpenSettings: () {},
      );

  test('suggestFrequentApp → pending 설정 + Suggestion 메시지', () async {
    final c = ctrl();
    final ok = await c.suggestFrequentApp(usages: const []);
    expect(ok, isTrue);
    expect(c.pendingSuggestionAppId, 'ota_monitor');
    expect(c.messages.last.intent, 'Suggestion');
  });

  test('suggestFrequentApp → 이미 pending 이면 false', () async {
    final c = ctrl();
    await c.suggestFrequentApp(usages: const []);
    expect(await c.suggestFrequentApp(usages: const []), isFalse);
  });

  test('acceptSuggestion → 앱 오픈 + pending 해제', () async {
    final opened = <String>[];
    final c = ctrl(onOpen: (a) => opened.add(a.id));
    await c.suggestFrequentApp(usages: const []);
    c.acceptSuggestion();
    expect(opened, contains('ota_monitor'));
    expect(c.pendingSuggestionAppId, isNull);
  });

  test('declineSuggestion → pending 해제', () async {
    final c = ctrl();
    await c.suggestFrequentApp(usages: const []);
    c.declineSuggestion();
    expect(c.pendingSuggestionAppId, isNull);
  });

  test('suggestFrequentApp → 앱 없으면 false', () async {
    final c = ctrl(apps: const []);
    expect(await c.suggestFrequentApp(usages: const []), isFalse);
  });

  test('submitLocalCommand 미등록 → Standard 메시지', () {
    final c = ctrl();
    c.submitLocalCommand('완전 모르는 명령어');
    expect(c.messages.last.intent, 'Standard');
  });

  test('submitLocalCommand 빈 입력 → no-op', () {
    final c = ctrl();
    final before = c.messages.length;
    c.submitLocalCommand('   ');
    expect(c.messages.length, before);
  });

  test('updateContext / updateRouter', () {
    final c = ctrl();
    c.updateContext('OTA');
    expect(c.contextName, 'OTA');
    c.updateRouter(NluRouter([_m('lfc_monitor')]));
  });
}
