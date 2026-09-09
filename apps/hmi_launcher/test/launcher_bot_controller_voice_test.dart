// QA(docs/qa): LauncherBotController 미커버 경로 — 음성(submitVoice) + quick actions.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_controller.dart';
import 'package:hmi_launcher/launcher_bot/services/voice_input_service.dart';

/// transcribeAudio 결과를 주입 가능한 fake. [transcript] 가 null 이면 throw.
class _VoiceAi implements LauncherBotAiService {
  const _VoiceAi(this.transcript);
  final String? transcript;

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) async {
    if (transcript == null) throw StateError('mic offline');
    return transcript!;
  }

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async =>
      'generated: $prompt';

  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async =>
      null;

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
      entry: '$id/main.dart', prompts: ['$id 열어줘'],
    );

CapturedVoiceInput _voice() => CapturedVoiceInput(
      pcm: Float32List(8),
      sampleRate: 16000,
      channels: 1,
      wavPath: '/tmp/rec.wav',
      durationSeconds: 1.5,
      peakAmplitude: 0.4,
      rmsAmplitude: 0.1,
      silentFrameRatio: 0.2,
    );

LauncherBotController _ctrl(LauncherBotAiService ai,
        {ValueChanged<AppManifest>? onOpen}) =>
    LauncherBotController(
      nluRouter: NluRouter([_m('ota_monitor'), _m('adsw_monitor')]),
      aiService: ai,
      onOpenApp: onOpen ?? (_) {},
      onCloseApp: () => 'ota_monitor',
      onOpenSettings: () {},
    );

void main() {
  test('submitVoice: 인식 텍스트가 명령이면 앱을 연다', () async {
    AppManifest? opened;
    final c = _ctrl(const _VoiceAi('ota_monitor 열어줘'),
        onOpen: (a) => opened = a);
    await c.submitVoice(_voice());
    expect(c.isGenerating, isFalse);
    expect(opened?.id, 'ota_monitor');
    expect(c.messages, isNotEmpty);
  });

  test('submitVoice: 빈 인식 결과 → 안내 메시지', () async {
    final c = _ctrl(const _VoiceAi('   '));
    await c.submitVoice(_voice());
    final texts = c.messages.map((m) => m.text).join('\n');
    expect(texts, contains('비어'));
    expect(texts, contains('/tmp/rec.wav'));
  });

  test('submitVoice: 인식 실패(throw) → 에러 + 디버그 메시지', () async {
    final c = _ctrl(const _VoiceAi(null));
    await c.submitVoice(_voice());
    final texts = c.messages.map((m) => m.text).join('\n');
    expect(texts, contains('실패'));
    expect(texts, contains('/tmp/rec.wav'));
    expect(c.isGenerating, isFalse);
  });

  test('submitVoice: 생성 중이면 재진입 무시', () async {
    final c = _ctrl(const _VoiceAi('ota_monitor 열어줘'));
    final f1 = c.submitVoice(_voice()); // 첫 호출이 isGenerating 세팅
    final f2 = c.submitVoice(_voice()); // 재진입 — 즉시 반환
    await Future.wait([f1, f2]);
    expect(c.isGenerating, isFalse);
  });

  test('quick actions: analyze/alerts/summarize 각각 메시지 추가', () {
    final c = _ctrl(const _VoiceAi(''));
    final before = c.messages.length;
    c.analyzeCurrentContext();
    c.showAlerts();
    c.summarizeCurrentContext();
    expect(c.messages.length, before + 3);
    final joined = c.messages.map((m) => m.text).join('\n');
    expect(joined, contains('ready'));
    expect(joined, contains('No active warnings'));
    expect(joined, contains('selected'));
  });

  test('updateContext 반영 후 quick action 텍스트에 컨텍스트명 포함', () {
    final c = _ctrl(const _VoiceAi(''));
    c.updateContext('OTA Monitor');
    expect(c.contextName, 'OTA Monitor');
    c.showAlerts();
    expect(c.messages.last.text, contains('OTA Monitor'));
  });
}
