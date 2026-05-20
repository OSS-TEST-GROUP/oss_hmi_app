import 'dart:convert';
import 'dart:typed_data';

import '../../domain/app_manifest.dart';
import 'gemma_chatbot_service.dart';

enum LauncherBotAiIntentAction { openApp, closeApp, openSettings, answer }

class LauncherBotAiIntent {
  const LauncherBotAiIntent({
    required this.action,
    this.appId,
  });

  final LauncherBotAiIntentAction action;
  final String? appId;
}

abstract class LauncherBotAiService {
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  });

  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  });

  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
    return null;
  }

  void dispose() {}
}

class GemmaLauncherBotAiService implements LauncherBotAiService {
  GemmaLauncherBotAiService({GemmaChatbotService? chatbotService})
      : _chatbotService = chatbotService ?? GemmaChatbotService();

  static bool isAvailable() => GemmaChatbotService.isRuntimeAvailable();

  final GemmaChatbotService _chatbotService;

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) {
    final request = _buildRequest(prompt: prompt, contexts: contexts);
    return _chatbotService.generate(request);
  }

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) async {
    final hasAudio = await _chatbotService.hasAudio();
    if (!hasAudio) {
      throw const GemmaChatbotException(
        '현재 모델이 오디오 입력을 지원하지 않습니다. mmproj 설정을 확인해 주세요.',
      );
    }

    final response = await _chatbotService.generateAudio(
      prompt: '이 오디오를 한국어 텍스트로 정확히 받아쓰기만 해줘. '
          '짧은 차량 명령어도 놓치지 말고 받아써. '
          '명령 의도 설명이나 부가 설명은 쓰지 말고, 사용자가 말한 문장만 출력해. '
          '특수 토큰, turn marker, markdown은 출력하지 마.',
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
    );
    if (response.trim().isNotEmpty) {
      return response;
    }

    return _chatbotService.generateAudio(
      prompt: '오디오에 아주 짧은 한국어 명령이 들어있을 수 있다. '
          '들리는 단어만 그대로 받아써. 예: "닫아줘", "설정 닫아줘", "OTA 실행해줘". '
          '아무 설명 없이 들린 문장만 출력해.',
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
    final request = _buildIntentRequest(
      prompt: prompt,
      apps: apps,
      currentContext: currentContext,
    );
    final response = await _chatbotService.generate(request);
    return _parseIntentResponse(response, apps);
  }

  String _buildRequest({
    required String prompt,
    required List<String> contexts,
  }) {
    if (contexts.isEmpty) return prompt;

    final contextText = contexts.join('\n');
    return '참고 정보:\n$contextText\n\n사용자 질문:\n$prompt';
  }

  String _buildIntentRequest({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) {
    final appText = apps
        .map(
          (app) => {
            'id': app.id,
            'name': app.name,
            'category': app.category,
            'prompts': app.prompts,
          },
        )
        .map(jsonEncode)
        .join('\n');

    return '''
너는 차량 런처의 intent router다.
사용자 요청이 앱 실행, 현재 앱 종료, 설정 열기인지 판단해라.
등록된 앱 목록에 없는 앱은 선택하지 마라.
일반 질문이나 대화면 answer를 선택해라.
사용자가 앱 이름 없이 "닫아줘", "종료해줘", "닫기"처럼 말하면 현재 화면 종료로 판단하고 appId를 넣지 마라.
앱 이름이 명확할 때만 close_app에 appId를 넣어라.
반드시 JSON 한 개만 출력해라. 설명, markdown, 코드블록은 출력하지 마라.

출력 형식:
{"action":"open_app","appId":"ota_monitor"}
{"action":"close_app","appId":"ota_monitor"}
{"action":"open_settings"}
{"action":"answer"}

현재 화면: $currentContext
등록된 앱:
$appText

사용자 요청: $prompt
''';
  }

  LauncherBotAiIntent? _parseIntentResponse(
    String response,
    List<AppManifest> apps,
  ) {
    final jsonText = _extractJsonObject(response);
    if (jsonText == null) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final action = decoded['action'];
    final appId = decoded['appId'];
    final validAppIds = apps.map((app) => app.id).toSet();

    if (action == 'open_app') {
      if (appId is! String || !validAppIds.contains(appId)) return null;
      return LauncherBotAiIntent(
        action: LauncherBotAiIntentAction.openApp,
        appId: appId,
      );
    }
    if (action == 'close_app') {
      if (appId is String && validAppIds.contains(appId)) {
        return LauncherBotAiIntent(
          action: LauncherBotAiIntentAction.closeApp,
          appId: appId,
        );
      }
      return const LauncherBotAiIntent(
        action: LauncherBotAiIntentAction.closeApp,
      );
    }
    if (action == 'open_settings') {
      return const LauncherBotAiIntent(
        action: LauncherBotAiIntentAction.openSettings,
      );
    }
    if (action == 'answer') {
      return const LauncherBotAiIntent(
          action: LauncherBotAiIntentAction.answer);
    }
    return null;
  }

  String? _extractJsonObject(String response) {
    final trimmed = response.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return trimmed.substring(start, end + 1);
  }

  @override
  void dispose() {
    _chatbotService.dispose();
  }
}

class FallbackLauncherBotAiService implements LauncherBotAiService {
  const FallbackLauncherBotAiService();

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
    return null;
  }

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final contextLabel = contexts.isEmpty ? 'Launcher' : contexts.first;
    return 'AI SDK is ready to be connected. For now I received "$prompt" in $contextLabel.';
  }

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) {
    throw const GemmaChatbotException('AI SDK 오디오 입력을 사용할 수 없습니다.');
  }

  @override
  void dispose() {}
}
