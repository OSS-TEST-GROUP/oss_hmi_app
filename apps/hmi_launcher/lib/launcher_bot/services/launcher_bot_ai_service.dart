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

  final GemmaChatbotService _chatbotService;

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) {
    if (contexts.isEmpty) return _chatbotService.generate(prompt);
    return _chatbotService.generateWithContexts(prompt, contexts);
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
