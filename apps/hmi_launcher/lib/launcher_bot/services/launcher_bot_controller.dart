import 'package:flutter/foundation.dart';

import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../models/launcher_bot_message.dart';
import 'launcher_bot_ai_service.dart';
import 'voice_input_service.dart';

class LauncherBotController extends ChangeNotifier {
  LauncherBotController({
    required NluRouter nluRouter,
    required LauncherBotAiService aiService,
    required ValueChanged<AppManifest> onOpenApp,
    required String? Function() onCloseApp,
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
  final String? Function() _onCloseApp;
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

    _addUserMessage(input);
    await _handleSubmittedInput(input);
  }

  Future<void> _handleSubmittedInput(String input) async {
    if (_handleDirectCommand(input)) return;

    _isGenerating = true;
    notifyListeners();

    try {
      if (await _handleAiCommand(input)) return;
    } catch (_) {
      // If the model cannot produce a valid route, fall back to the local
      // router and finally to normal answer generation below.
    } finally {
      _isGenerating = false;
      notifyListeners();
    }

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

  Future<void> submitVoice(CapturedVoiceInput voice) async {
    if (_isGenerating) return;

    final userIndex = _messages.length;
    _addMessage(
      LauncherBotMessage(
        speaker: LauncherBotSpeaker.user,
        text: '음성 인식 중...',
        timestamp: _nowLabel(),
      ),
    );

    _isGenerating = true;
    notifyListeners();

    try {
      final recognizedText = (await _aiService.transcribeAudio(
        pcm: voice.pcm,
        sampleRate: voice.sampleRate,
        channels: voice.channels,
      ))
          .trim();

      if (recognizedText.isEmpty) {
        _messages[userIndex] = _messages[userIndex].copyWith(
          text: '음성 인식 결과가 비어 있습니다.',
          timestamp: _nowLabel(),
        );
        _addBotMessage('음성 내용을 인식하지 못했습니다.', intent: 'Voice');
        return;
      }

      _messages[userIndex] = _messages[userIndex].copyWith(
        text: recognizedText,
        timestamp: _nowLabel(),
      );
      notifyListeners();
      _isGenerating = false;
      await _handleSubmittedInput(recognizedText);
    } catch (error) {
      _messages[userIndex] = _messages[userIndex].copyWith(
        text: '음성 인식 실패',
        timestamp: _nowLabel(),
      );
      _addBotMessage('음성 인식에 실패했습니다. $error', intent: 'Voice Error');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void submitLocalCommand(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty || _isGenerating) return;

    _addUserMessage(input);
    if (_handleLocalCommand(input)) return;
    _addBotMessage('Standard 모드에서는 등록된 명령만 실행할 수 있어요.', intent: 'Standard');
  }

  void _addUserMessage(String input) {
    _addMessage(
      LauncherBotMessage(
        speaker: LauncherBotSpeaker.user,
        text: input,
        timestamp: _nowLabel(),
      ),
    );
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
    if (_handleDirectCommand(input)) return true;

    final route = _nluRouter.resolveIntent(input);
    if (route != null) {
      if (route.action == NluRouteAction.close) {
        if (_contextName == route.app.name) {
          final closedName = _onCloseApp();
          _addCloseMessage(closedName, intent: 'Close App');
        } else {
          _addBotMessage(
            '${route.app.name}은 현재 열려 있지 않아요.',
            intent: 'Close App',
          );
        }
      } else {
        _onOpenApp(route.app);
        _addBotMessage('${route.app.name}을 실행했어요.', intent: 'Open App');
      }
      return true;
    }

    return false;
  }

  bool _handleDirectCommand(String input) {
    if (_isCloseCommand(input) || _isCloseSettingsCommand(input)) {
      final closedName = _onCloseApp();
      _addCloseMessage(closedName, intent: 'Close');
      return true;
    }

    if (_isSettingsCommand(input)) {
      _onOpenSettings();
      _addBotMessage('설정 화면을 열었어요.', intent: 'Open Settings');
      return true;
    }

    return false;
  }

  Future<bool> _handleAiCommand(String input) async {
    final intent = await _aiService.resolveIntent(
      prompt: input,
      apps: _nluRouter.apps,
      currentContext: _contextName,
    );
    if (intent == null || intent.action == LauncherBotAiIntentAction.answer) {
      return false;
    }

    switch (intent.action) {
      case LauncherBotAiIntentAction.openApp:
        final app = _appById(intent.appId);
        if (app == null) return false;
        _onOpenApp(app);
        _addBotMessage('${app.name}을 실행했어요.', intent: 'AI Open App');
        return true;
      case LauncherBotAiIntentAction.closeApp:
        final app = _appById(intent.appId);
        if (app != null && _contextName != app.name) {
          _addBotMessage(
            '${app.name}은 현재 열려 있지 않아요.',
            intent: 'AI Close App',
          );
          return true;
        }
        final closedName = _onCloseApp();
        _addCloseMessage(closedName ?? app?.name, intent: 'AI Close App');
        return true;
      case LauncherBotAiIntentAction.openSettings:
        _onOpenSettings();
        _addBotMessage('설정 화면을 열었어요.', intent: 'AI Open Settings');
        return true;
      case LauncherBotAiIntentAction.answer:
        return false;
    }
  }

  AppManifest? _appById(String? appId) {
    if (appId == null) return null;
    for (final app in _nluRouter.apps) {
      if (app.id == appId) return app;
    }
    return null;
  }

  bool _isCloseCommand(String input) {
    final normalized = _normalizeCommand(input);
    const commands = {
      'close',
      'closeapp',
      'exit',
      'exitapp',
      'quit',
      'back',
      'home',
      'gohome',
      'backtohome',
      '홈',
      '홈으로',
      '닫기',
      '닫아',
      '닫아줘',
      '종료',
      '나가기',
      '뒤로',
      '뒤로가기',
    };
    return commands.contains(normalized);
  }

  bool _isCloseSettingsCommand(String input) {
    final normalized = _normalizeCommand(input);
    final hasSettings =
        normalized.contains('설정') || normalized.contains('setting');
    return hasSettings && _hasCloseKeyword(normalized);
  }

  bool _hasCloseKeyword(String normalizedInput) {
    return normalizedInput.contains('닫') ||
        normalizedInput.contains('종료') ||
        normalizedInput.contains('나가') ||
        normalizedInput.contains('뒤로') ||
        normalizedInput.contains('close') ||
        normalizedInput.contains('exit') ||
        normalizedInput.contains('quit') ||
        normalizedInput.contains('back');
  }

  bool _isSettingsCommand(String input) {
    final normalized = input.trim().toLowerCase();
    return normalized.contains('settings') ||
        normalized.contains('setting') ||
        input.contains('설정');
  }

  String _normalizeCommand(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]+'), '');
  }

  List<String> _buildContexts() {
    return [
      '현재 화면: $_contextName',
      '앱 실행, 설정 열기, 앱 닫기는 AI intent router와 런처가 먼저 처리합니다.',
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

  void _addCloseMessage(String? closedName, {String? intent}) {
    if (closedName == null || closedName == 'Launcher') {
      _addBotMessage('닫을 앱이 없어요.', intent: intent);
      return;
    }
    _addBotMessage('$closedName을 닫았어요.', intent: intent);
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
