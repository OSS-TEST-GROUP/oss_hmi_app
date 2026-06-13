// F015: GemmaLauncherBotAiService 는 더 이상 dart:ffi 를 통한 LLM 직접 호출을 하지 않는다.
// 내장 LLM FFI 는 F015 에서 제거됐으며 GemmaChatbotService 는 빈 스텁으로 대체됐다.
// 새 코드는 AgentSubmitAiService (agent_submit_ai_service.dart) 를 사용하라.
import 'dart:typed_data';

import '../../domain/app_manifest.dart';
import 'app_usage_store.dart';
import 'gemma_chatbot_service.dart';

enum LauncherBotAiIntentAction { openApp, closeApp, openSettings, answer }

class LauncherBotAiIntent {
  const LauncherBotAiIntent({
    required this.action,
    this.appId,
    this.answer,
  });

  final LauncherBotAiIntentAction action;
  final String? appId;
  final String? answer;
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

/// F015: 내장 Gemma LLM 기반 AI 서비스 (deprecated — F015 에서 사용 중단).
///
/// chatbot_bridge / llama_cpp FFI 가 F015 에서 제거됐다.
/// GemmaChatbotService 는 이제 빈 스텁이므로 이 클래스의 실제 AI 기능은 동작하지 않는다.
/// 새 코드는 [AgentSubmitAiService] 를 사용하라.
/// 이 클래스는 기존 테스트 코드와의 호환성 유지를 위해 이름만 남긴다.
@Deprecated('Use AgentSubmitAiService instead. F015: FFI removed.')
class GemmaLauncherBotAiService implements LauncherBotAiService {
  GemmaLauncherBotAiService({GemmaChatbotService? chatbotService})
      : _chatbotService = chatbotService ?? GemmaChatbotService();

  /// F015: 내장 LLM 런타임은 항상 사용 불가 (FFI 제거됨).
  static bool isAvailable() => GemmaChatbotService.isRuntimeAvailable();

  // ignore: deprecated_member_use_from_same_package
  final GemmaChatbotService _chatbotService;

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async {
    // F015: FFI 가 제거됐으므로 chatbotService 는 응답을 생성할 수 없다.
    // 이 경로는 LauncherBotController 의 폴백 generate() 에서 호출되나
    // AgentSubmitAiService 사용 시에는 도달하지 않는다.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return '(내장 LLM 이 비활성화됐습니다. Agent gRPC 서비스를 연결하세요.)';
  }

  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async {
    return null;
  }

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) {
    throw const GemmaChatbotException(
      '내장 LLM FFI 가 F015 에서 제거됐습니다. 오디오 전사를 사용할 수 없습니다.',
    );
  }

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
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
