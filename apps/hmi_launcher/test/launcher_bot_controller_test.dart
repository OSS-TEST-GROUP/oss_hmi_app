import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';
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
}

class _FakeAiService implements LauncherBotAiService {
  const _FakeAiService(this.intent);

  final LauncherBotAiIntent? intent;

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async {
    return 'fallback answer';
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
  void dispose() {}
}
