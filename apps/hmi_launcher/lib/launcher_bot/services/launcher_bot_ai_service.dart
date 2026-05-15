import 'gemma_chatbot_service.dart';

abstract class LauncherBotAiService {
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  });

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

  String _buildRequest({
    required String prompt,
    required List<String> contexts,
  }) {
    if (contexts.isEmpty) return prompt;

    final contextText = contexts.join('\n');
    return '참고 정보:\n$contextText\n\n사용자 질문:\n$prompt';
  }

  @override
  void dispose() {
    _chatbotService.dispose();
  }
}

class FallbackLauncherBotAiService implements LauncherBotAiService {
  const FallbackLauncherBotAiService();

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
  void dispose() {}
}
