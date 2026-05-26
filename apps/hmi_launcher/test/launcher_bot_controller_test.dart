import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_controller.dart';

void main() {
  test('AI intent can route app launch before local NLU matching', () async {
    final ota = AppManifest(
      id: 'ota_monitor',
      name: 'OTA Monitor',
      icon: 'box',
      version: '1.0.0',
      entry: 'ota_monitor/main.dart',
      prompts: const ['OTA 모니터 열어줘'],
    );
    final controller = LauncherBotController(
      nluRouter: NluRouter([ota]),
      aiService: const _FakeAiService(
        LauncherBotAiIntent(
          action: LauncherBotAiIntentAction.openApp,
          appId: 'ota_monitor',
        ),
      ),
      onOpenApp: (app) => expect(app.id, 'ota_monitor'),
      onCloseApp: () => fail('close should not be called'),
      onOpenSettings: () => fail('settings should not be called'),
    );

    await controller.submit('업데이트 상태 화면 좀 보여줘');

    expect(controller.messages.last.text, 'OTA Monitor을 실행했어요.');
    expect(controller.messages.last.intent, 'AI Open App');
  });

  test('generic close closes current context before AI intent routing',
      () async {
    var closeCalled = false;
    final controller = LauncherBotController(
      nluRouter: NluRouter(const []),
      aiService: const _FakeAiService(
        LauncherBotAiIntent(
          action: LauncherBotAiIntentAction.openApp,
          appId: 'ota_monitor',
        ),
      ),
      onOpenApp: (_) => fail('open should not be called'),
      onCloseApp: () {
        closeCalled = true;
        return 'AD SW';
      },
      onOpenSettings: () => fail('settings should not be called'),
      contextName: 'AD SW',
    );

    await controller.submit('닫아줘.');

    expect(closeCalled, isTrue);
    expect(controller.messages.last.text, 'AD SW을 닫았어요.');
    expect(controller.messages.last.intent, 'Close');
  });

  test(
      'settings close command closes current screen instead of opening settings',
      () async {
    var closeCalled = false;
    var settingsCalled = false;
    final controller = LauncherBotController(
      nluRouter: NluRouter(const []),
      aiService: const _FakeAiService(
        LauncherBotAiIntent(action: LauncherBotAiIntentAction.openSettings),
      ),
      onOpenApp: (_) => fail('open should not be called'),
      onCloseApp: () {
        closeCalled = true;
        return 'Settings';
      },
      onOpenSettings: () => settingsCalled = true,
      contextName: 'Settings',
    );

    await controller.submit('설정 닫아줘.');

    expect(closeCalled, isTrue);
    expect(settingsCalled, isFalse);
    expect(controller.messages.last.text, 'Settings을 닫았어요.');
    expect(controller.messages.last.intent, 'Close');
  });

  test('app suggestion message always includes selected app name', () async {
    final ota = AppManifest(
      id: 'ota_monitor',
      name: 'OTA Monitor',
      icon: 'box',
      version: '1.0.0',
      entry: 'ota_monitor/main.dart',
      prompts: const ['OTA 모니터 열어줘'],
    );
    final controller = LauncherBotController(
      nluRouter: NluRouter([ota]),
      aiService: const _FakeAiService(
        null,
        suggestionMessage: '자주 실행하는 앱을 지금 실행할까요?',
      ),
      onOpenApp: (_) {},
      onCloseApp: () => null,
      onOpenSettings: () {},
    );

    final shown = await controller.suggestFrequentApp(
      usages: [
        AppUsageStats(
          appId: 'ota_monitor',
          openCount: 3,
          lastOpenedAt: DateTime(2026, 5, 26, 10),
          totalForegroundSeconds: 120,
        ),
      ],
    );

    expect(shown, isTrue);
    expect(controller.messages.last.text, contains('OTA Monitor'));
    expect(controller.messages.last.text, '최근 OTA Monitor을 자주 열었어요. 지금 실행할까요?');
  });
}

class _FakeAiService implements LauncherBotAiService {
  const _FakeAiService(this.intent, {this.suggestionMessage});

  final LauncherBotAiIntent? intent;
  final String? suggestionMessage;

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async {
    return 'fallback answer';
  }

  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async {
    if (apps.isEmpty) return null;
    return LauncherBotAiAppSuggestion(
      appId: apps.first.id,
      message: suggestionMessage ?? '최근 ${apps.first.name}을 자주 열었어요. 지금 실행할까요?',
    );
  }

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
    return intent;
  }

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) async {
    return 'recognized voice';
  }

  @override
  void dispose() {}
}
