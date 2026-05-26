import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/app_manifest.dart';
import 'app_usage_store.dart';
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

class LauncherBotAiAppSuggestion {
  const LauncherBotAiAppSuggestion({
    required this.appId,
    required this.message,
  });

  final String appId;
  final String message;
}

abstract class LauncherBotAiService {
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  });

  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
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
  }) async {
    return _generateNormalAnswer(prompt);
  }

  Future<String> _generateNormalAnswer(String prompt) async {
    final response = (await _chatbotService.generate(prompt)).trim();
    if (_isUsableAnswer(response, prompt)) {
      return response;
    }

    stderr.writeln(
      '[GemmaLauncherBotAiService] normal generation returned unusable '
      'response. prompt=[$prompt] response=[$response]',
    );
    return '답변을 생성하지 못했습니다. AI 응답이 비어 있거나 질문과 동일하게 반환되었습니다.';
  }

  bool _isUsableAnswer(String response, String prompt) {
    final answer = response.trim();
    if (answer.isEmpty) return false;
    final question = prompt.trim();
    if (question.isNotEmpty && answer == question) return false;
    return true;
  }

  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async {
    if (apps.isEmpty || usages.isEmpty) return null;

    final request = _buildAppSuggestionRequest(
      apps: apps,
      usages: usages,
      currentContext: currentContext,
    );
    stderr.writeln(
      '[GemmaLauncherBotAiService] app_suggestion start '
      'context=[$currentContext] candidates=${usages.length}',
    );
    final response = await _chatbotService.generate(request);
    stderr.writeln(
      '[GemmaLauncherBotAiService] app_suggestion raw_response=[$response]',
    );
    final suggestion = _parseAppSuggestionResponse(response, apps);
    stderr.writeln(
      '[GemmaLauncherBotAiService] app_suggestion parsed='
      '${suggestion == null ? 'null' : '${suggestion.appId}: ${suggestion.message}'}',
    );
    return suggestion;
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
      prompt: _audioTranscriptPrompt,
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
    );
    if (response.trim().isNotEmpty) {
      return response;
    }

    return _chatbotService.generateAudio(
      prompt: _shortAudioTranscriptPrompt,
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  static const _audioTranscriptPrompt = '''
이 오디오는 차량 런처에 말하는 짧은 명령 또는 질문이다.
한국어/영어가 섞일 수 있다.

가능한 앱/화면 이름:
- AD SW
- AD SW Monitor
- OTA
- OTA Monitor
- Settings
- 설정

가능한 실행 표현:
- 실행해줘
- 실행
- 열어줘
- 열기
- 보여줘
- 시작해줘
- 시작
- open
- run
- start

가능한 종료 표현:
- 닫아줘
- 닫기
- 종료해줘
- 종료
- 꺼줘
- close

발음 보정:
- "오티에이", "오티 에이"는 "OTA"로 보정해라.
- "에이디 에스더블유", "에이디 에스 더블유", "AD 에스더블유"는 "AD SW"로 보정해라.

출력 규칙:
- 들리는 내용을 가장 가까운 자연스러운 명령 문장으로 한 줄만 출력해라.
- 예: "AD SW 실행해줘", "OTA Monitor 열어줘", "설정 닫아줘", "open OTA"
- 설명, 의도 분석, markdown, 특수 토큰, turn marker는 출력하지 마라.
''';

  static const _shortAudioTranscriptPrompt = '''
오디오에 매우 짧은 차량 런처 명령이 들어있을 수 있다.
가능한 앱은 AD SW, AD SW Monitor, OTA, OTA Monitor, Settings, 설정이다.
가능한 동작은 실행, 열기, open, 닫기, 종료, close다.
"오티에이"는 "OTA"로, "에이디 에스더블유"는 "AD SW"로 보정해라.
아무 설명 없이 들린 명령 문장만 한 줄로 출력해라.
''';

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
반드시 아래 두 형식 중 하나만 골라 JSON 한 개만 출력해라.
설명, markdown, 코드블록, 추가 JSON은 출력하지 마라.

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

  String _buildAppSuggestionRequest({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) {
    final appById = {for (final app in apps) app.id: app};
    final usageText = usages
        .where((usage) => appById.containsKey(usage.appId))
        .map((usage) {
          final app = appById[usage.appId]!;
          return {
            'id': app.id,
            'name': app.name,
            'category': app.category,
            'openCount': usage.openCount,
            'totalForegroundSeconds': usage.totalForegroundSeconds,
            'lastOpenedAt': usage.lastOpenedAt.toIso8601String(),
          };
        })
        .map(jsonEncode)
        .join('\n');

    return '''
너는 차량 런처의 선제적 에이전트다.
사용자의 앱 사용 패턴과 현재 화면을 보고 지금 먼저 실행 제안을 할 앱을 하나 고른다.
단순히 문장만 만들지 말고, 어떤 앱을 제안할지 직접 판단해라.
openCount, totalForegroundSeconds, lastOpenedAt을 모두 고려해라.
앱 사용 패턴은 openCount, totalForegroundSeconds, lastOpenedAt 기준으로 추천 우선순위가 높은 순서로 정렬되어 있다.
어떤 앱이 다른 앱보다 openCount와 totalForegroundSeconds가 모두 높고 lastOpenedAt도 더 최신이면 그 앱을 선택해라.
등록된 앱 id 중 하나만 고를 수 있다.
현재 화면이 Launcher가 아니면 suggest=false로 해라.
사용 패턴이 부족하거나 확신이 낮으면 suggest=false로 해라.
제안할 때는 짧고 자연스러운 한국어 질문 문장을 함께 만든다.
message에는 반드시 선택한 앱의 name을 포함해라.
반드시 JSON 한 개만 출력해라. 설명, markdown, 코드블록, 추가 JSON은 출력하지 마라.
아래 출력 형식의 appId 예시는 placeholder다. 그대로 복사하지 말고 앱 사용 패턴에 있는 실제 id만 사용해라.

출력 형식 예시:
{"suggest":true,"appId":"<registered_app_id>","message":"최근 <app name>을 자주 열었어요. 지금 실행할까요?"}
{"suggest":false}

현재 화면: $currentContext
앱 사용 패턴:
$usageText
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

  LauncherBotAiAppSuggestion? _parseAppSuggestionResponse(
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
    if (decoded['suggest'] != true) return null;

    final appId = decoded['appId'];
    final message = decoded['message'];
    final validAppIds = apps.map((app) => app.id).toSet();
    if (appId is! String || !validAppIds.contains(appId)) return null;
    if (message is! String || message.trim().isEmpty) return null;

    return LauncherBotAiAppSuggestion(
      appId: appId,
      message: message.trim(),
    );
  }

  String? _extractJsonObject(String response) {
    final trimmed = response.trim();
    final start = trimmed.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaping = false;
    for (var index = start; index < trimmed.length; index += 1) {
      final char = trimmed[index];
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char == r'\') {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return trimmed.substring(start, index + 1);
        }
      }
    }
    return null;
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
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async {
    if (currentContext != 'Launcher') return null;
    AppUsageStats? best;
    for (final usage in usages) {
      if (best == null ||
          usage.openCount > best.openCount ||
          (usage.openCount == best.openCount &&
              usage.lastOpenedAt.isAfter(best.lastOpenedAt))) {
        best = usage;
      }
    }
    if (best == null) return null;
    for (final app in apps) {
      if (app.id == best.appId) {
        return LauncherBotAiAppSuggestion(
          appId: app.id,
          message: '최근 ${app.name}을 자주 열었어요. 지금 실행할까요?',
        );
      }
    }
    return null;
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
