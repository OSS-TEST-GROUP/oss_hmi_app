// F015: 내장 Gemma LLM FFI 는 F015 에서 완전 제거됐다.
// 새 코드는 AgentSubmitAiService (agent_submit_ai_service.dart) 를 사용한다.
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
