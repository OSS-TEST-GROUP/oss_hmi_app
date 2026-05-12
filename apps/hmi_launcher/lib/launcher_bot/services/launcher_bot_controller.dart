import 'package:flutter/foundation.dart';

import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../models/launcher_bot_message.dart';
import 'launcher_bot_ai_service.dart';

class LauncherBotController extends ChangeNotifier {
  LauncherBotController({
    required NluRouter nluRouter,
    required LauncherBotAiService aiService,
    required ValueChanged<AppManifest> onOpenApp,
    required VoidCallback onCloseApp,
    required VoidCallback onOpenSettings,
    String contextName = 'Launcher',
  })  : _nluRouter = nluRouter,
        _aiService = aiService,
        _onOpenApp = onOpenApp,
        _onCloseApp = onCloseApp,
        _onOpenSettings = onOpenSettings,
        _contextName = contextName {
    _messages.add(
      LauncherBotMessage(
        speaker: LauncherBotSpeaker.bot,
        text:
            'Launcher Bot is ready. Tell me which app to open, or ask a question.',
        timestamp: _nowLabel(),
        intent: 'Ready',
      ),
    );
  }

  NluRouter _nluRouter;
  final LauncherBotAiService _aiService;
  final ValueChanged<AppManifest> _onOpenApp;
  final VoidCallback _onCloseApp;
  final VoidCallback _onOpenSettings;
  String _contextName;

  final List<LauncherBotMessage> _messages = [];
  bool _isGenerating = false;

  List<LauncherBotMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  String get contextName => _contextName;

  void updateRouter(NluRouter router) {
    _nluRouter = router;
  }

  void updateContext(String contextName) {
    if (_contextName == contextName) return;
    _contextName = contextName;
  }

  Future<void> submit(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty || _isGenerating) return;

    _addMessage(
      LauncherBotMessage(
        speaker: LauncherBotSpeaker.user,
        text: input,
        timestamp: _nowLabel(),
      ),
    );

    if (_handleLocalCommand(input)) return;

    final pendingIndex = _messages.length;
    _isGenerating = true;
    _addMessage(
      LauncherBotMessage(
        speaker: LauncherBotSpeaker.bot,
        text: '답변 생성중...',
        timestamp: _nowLabel(),
        intent: 'AI',
      ),
    );

    try {
      final response = await _aiService.generate(
        prompt: input,
        contexts: _buildContexts(),
      );
      _messages[pendingIndex] = _messages[pendingIndex].copyWith(
        text: response.trim().isEmpty ? '응답 내용이 비어 있습니다.' : response.trim(),
        timestamp: _nowLabel(),
        intent: 'AI',
      );
    } catch (error) {
      _messages[pendingIndex] = _messages[pendingIndex].copyWith(
        text: 'AI 응답 생성에 실패했습니다. $error',
        timestamp: _nowLabel(),
        intent: 'Error',
      );
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void analyzeCurrentContext() {
    _addBotMessage(
      '$_contextName looks ready. Runtime is connected and there are no blocking alerts.',
      intent: 'Analyze',
    );
  }

  void showAlerts() {
    _addBotMessage('No active warnings for $_contextName.', intent: 'Alerts');
  }

  void summarizeCurrentContext() {
    _addBotMessage(
      '$_contextName is selected. You can open apps, close the current app, or update settings.',
      intent: 'Summary',
    );
  }

  bool _handleLocalCommand(String input) {
    if (_isCloseCommand(input)) {
      _onCloseApp();
      _addBotMessage('홈 화면으로 돌아왔어요.', intent: 'Close');
      return true;
    }

    if (_isSettingsCommand(input)) {
      _onOpenSettings();
      _addBotMessage('설정 화면을 열었어요.', intent: 'Open Settings');
      return true;
    }

    final app = _nluRouter.resolve(input);
    if (app != null) {
      _onOpenApp(app);
      _addBotMessage('${app.name}을 실행했어요.', intent: 'Open App');
      return true;
    }

    return false;
  }

  bool _isCloseCommand(String input) {
    const commands = {
      'close',
      'close app',
      'exit',
      'exit app',
      'quit',
      'back',
      'home',
      'go home',
      'back to home',
      '홈',
      '홈으로',
      '닫기',
      '닫아',
      '닫아줘',
      '종료',
      '나가기',
      '뒤로',
      '뒤로 가기',
    };
    return commands.contains(input.trim().toLowerCase());
  }

  bool _isSettingsCommand(String input) {
    final normalized = input.trim().toLowerCase();
    return normalized.contains('settings') ||
        normalized.contains('setting') ||
        input.contains('설정');
  }

  List<String> _buildContexts() {
    return [
      'Current launcher context: $_contextName',
      'Local commands are handled before AI: open app, close app, settings.',
    ];
  }

  void _addBotMessage(String text, {String? intent}) {
    _addMessage(
      LauncherBotMessage(
        speaker: LauncherBotSpeaker.bot,
        text: text,
        timestamp: _nowLabel(),
        intent: intent,
      ),
    );
  }

  void _addMessage(LauncherBotMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  String _nowLabel() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
