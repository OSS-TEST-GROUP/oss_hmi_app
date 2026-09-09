// QA(docs/qa): LauncherBotPanel 위젯 — AI 모드(입력/제출/닫기) + Standard 모드(명령칩).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_controller.dart';
import 'package:hmi_launcher/presentation/launcher_bot/launcher_bot_panel.dart';

class _FakeAi implements LauncherBotAiService {
  const _FakeAi();
  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async =>
      'ok';
  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async =>
      null;
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

/// suggestAppToOpen 이 항상 첫 앱을 추천하는 fake — 제안 메시지 렌더 검증용.
class _SuggestAi implements LauncherBotAiService {
  const _SuggestAi();
  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async =>
      'ok';
  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async =>
      apps.isEmpty
          ? null
          : LauncherBotAiAppSuggestion(
              appId: apps.first.id, message: '${apps.first.name} 실행할까요?');
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

AppManifest _m(String id, {String? name}) => AppManifest(
      id: id, name: name ?? id, icon: '📦', version: '1.0.0',
      entry: '$id/main.dart', prompts: ['$id 열어줘'],
    );

AppUsageStats _u(String id) => AppUsageStats(
      appId: id, openCount: 5, lastOpenedAt: DateTime(2026, 1, 1),
      totalForegroundSeconds: 120,
    );

LauncherBotController _ctrl({VoidCallback? onSettings}) => LauncherBotController(
      nluRouter: NluRouter([_m('ota_monitor', name: 'OTA')]),
      aiService: const _FakeAi(),
      onOpenApp: (_) {},
      onCloseApp: () => 'OTA',
      onOpenSettings: onSettings ?? () {},
    );

Future<void> _pump(
  WidgetTester tester, {
  required bool aiMode,
  required LauncherBotController controller,
  VoidCallback? onClose,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LauncherBotPanel(
        controller: controller,
        selectedName: 'Launcher',
        aiMode: aiMode,
        apps: [_m('ota_monitor', name: 'OTA')],
        onClose: onClose ?? () {},
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('AI 모드: 입력 후 제출 → controller.submit 호출', (tester) async {
    final c = _ctrl();
    await _pump(tester, aiMode: true, controller: c);
    final field = find.byKey(const Key('launcher_bot_input_field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'ota_monitor 열어줘');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.messages, isNotEmpty);
  });

  testWidgets('AI 모드: 헤더 닫기 버튼 → onClose', (tester) async {
    var closed = false;
    final c = _ctrl();
    await _pump(tester, aiMode: true, controller: c, onClose: () => closed = true);
    final closeBtn = find.byType(IconButton);
    if (closeBtn.evaluate().isNotEmpty) {
      await tester.tap(closeBtn.first, warnIfMissed: false);
      await tester.pump();
    }
    expect(closed, isTrue);
  });

  testWidgets('AI 모드: 제안 메시지 렌더 + Yes(수락) 탭', (tester) async {
    final c = LauncherBotController(
      nluRouter: NluRouter([_m('ota_monitor', name: 'OTA')]),
      aiService: const _SuggestAi(),
      onOpenApp: (_) {},
      onCloseApp: () => 'OTA',
      onOpenSettings: () {},
    );
    // 제안 메시지(Yes/No 액션 포함)를 먼저 만든다.
    final shown = await c.suggestFrequentApp(usages: [_u('ota_monitor')]);
    expect(shown, isTrue);
    await _pump(tester, aiMode: true, controller: c);
    // 제안 액션 버튼(Yes) 렌더 확인 + 탭.
    final yes = find.text('Yes');
    expect(yes, findsWidgets);
    await tester.ensureVisible(yes.first);
    await tester.tap(yes.first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.pendingSuggestionAppId, isNull); // 수락 후 제안 해제
  });

  testWidgets('Standard 모드: 명령 칩 탭 → submitLocalCommand', (tester) async {
    final c = _ctrl();
    await _pump(tester, aiMode: false, controller: c);
    final before = c.messages.length;
    // 앱 실행 칩 / 설정 칩 / 닫기 칩 중 탭 가능한 것들을 탭.
    for (final label in ['OTA 실행', '설정 열기', '현재 앱 닫기']) {
      final chip = find.text(label);
      if (chip.evaluate().isNotEmpty) {
        await tester.ensureVisible(chip.first);
        await tester.tap(chip.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    expect(c.messages.length, greaterThan(before));
  });
}
