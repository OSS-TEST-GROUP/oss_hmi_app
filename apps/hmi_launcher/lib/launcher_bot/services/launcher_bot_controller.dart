import 'package:flutter/foundation.dart';

import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../models/launcher_bot_message.dart';
import 'app_usage_store.dart';
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
            'Launcher Agent is ready. Tell me which app to open, or ask a question.',
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
  String? _pendingSuggestionAppId;

  List<LauncherBotMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  String get contextName => _contextName;
  String? get pendingSuggestionAppId => _pendingSuggestionAppId;

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

  Future<bool> suggestFrequentApp({
    required List<AppUsageStats> usages,
  }) async {
    if (_isGenerating || _pendingSuggestionAppId != null) return false;

    _isGenerating = true;
    notifyListeners();

    try {
      final suggestion = await _aiService.suggestAppToOpen(
        apps: _nluRouter.apps,
        usages: usages,
        currentContext: _contextName,
      );
      final app = _appById(suggestion?.appId);
      if (suggestion == null || app == null) return false;
      final suggestionText = _suggestionTextWithAppName(
        app,
        suggestion.message,
      );
      if (suggestionText.isEmpty) return false;

      _pendingSuggestionAppId = app.id;
      _addMessage(
        LauncherBotMessage(
          speaker: LauncherBotSpeaker.bot,
          text: suggestionText,
          timestamp: _nowLabel(),
          intent: 'Suggestion',
          actions: const [
            LauncherBotMessageAction(id: 'accept_suggestion', label: 'Yes'),
            LauncherBotMessageAction(id: 'decline_suggestion', label: 'No'),
          ],
        ),
      );
      return true;
    } catch (error) {
      debugPrint('[LauncherBotController] app suggestion failed: $error');
      // A proactive suggestion is optional; failed AI selection should not
      // interrupt launcher startup.
      return false;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void acceptSuggestion() {
    final app = _appById(_pendingSuggestionAppId);
    _pendingSuggestionAppId = null;
    _addUserMessage('Yes');
    if (app == null) {
      _addBotMessage('추천 앱을 찾을 수 없어요.', intent: 'Suggestion');
      return;
    }
    _onOpenApp(app);
    _addBotMessage('${app.name}을 실행했어요.', intent: 'Suggestion');
  }

  void declineSuggestion() {
    if (_pendingSuggestionAppId == null) return;
    _pendingSuggestionAppId = null;
    _addUserMessage('No');
    _addBotMessage('알겠어요. 홈 화면을 유지할게요.', intent: 'Suggestion');
  }

  Future<void> _handleSubmittedInput(String input) async {
    if (_handleDirectCommand(input)) return;

    final pendingIndex = _messages.length;
    final generationStartedAt = DateTime.now();
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
      try {
        if (await _handleAiCommand(
          input,
          pendingIndex: pendingIndex,
          startedAt: generationStartedAt,
        )) {
          return;
        }
      } catch (_) {
        // If the model cannot produce a valid route, fall back to the local
        // router and finally to normal answer generation below.
      }

      if (_handleLocalCommand(
        input,
        pendingIndex: pendingIndex,
        startedAt: generationStartedAt,
      )) {
        return;
      }

      final response = await _aiService.generate(
        prompt: input,
        contexts: _buildContexts(),
      );
      _messages[pendingIndex] = _messages[pendingIndex].copyWith(
        text: response.trim().isEmpty ? '응답 내용이 비어 있습니다.' : response.trim(),
        timestamp: _nowLabel(),
        intent: 'AI',
        details: _performanceLabel(generationStartedAt),
      );
    } catch (error) {
      _messages[pendingIndex] = _messages[pendingIndex].copyWith(
        text: 'AI 응답 생성에 실패했습니다. $error',
        timestamp: _nowLabel(),
        intent: 'Error',
        details: _performanceLabel(generationStartedAt),
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

    CapturedVoiceInput? capturedVoice;
    try {
      capturedVoice = voice;
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
        _addBotMessage(
          '음성 내용을 인식하지 못했습니다. 녹음 파일: ${voice.wavPath}\n'
          '${voice.debugSummary}',
          intent: 'Voice',
        );
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
      if (capturedVoice != null) {
        _addBotMessage(
          '녹음 파일: ${capturedVoice.wavPath}\n'
          '${capturedVoice.debugSummary}',
          intent: 'Voice Debug',
        );
      }
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

  bool _handleLocalCommand(
    String input, {
    int? pendingIndex,
    DateTime? startedAt,
  }) {
    if (_handleDirectCommand(
      input,
      pendingIndex: pendingIndex,
      startedAt: startedAt,
    )) {
      return true;
    }

    final route = _nluRouter.resolveIntent(input);
    if (route != null) {
      if (route.action == NluRouteAction.close) {
        if (_contextName == route.app.name) {
          final closedName = _onCloseApp();
          _addCloseMessage(
            closedName,
            intent: 'Close App',
            pendingIndex: pendingIndex,
            details: _performanceLabelOrNull(startedAt),
          );
        } else {
          _emitBotMessage(
            '${route.app.name}은 현재 열려 있지 않아요.',
            intent: 'Close App',
            pendingIndex: pendingIndex,
            details: _performanceLabelOrNull(startedAt),
          );
        }
      } else {
        _onOpenApp(route.app);
        _emitBotMessage(
          '${route.app.name}을 실행했어요.',
          intent: 'Open App',
          pendingIndex: pendingIndex,
          details: _performanceLabelOrNull(startedAt),
        );
      }
      return true;
    }

    return false;
  }

  bool _handleDirectCommand(
    String input, {
    int? pendingIndex,
    DateTime? startedAt,
  }) {
    if (_isCloseCommand(input) || _isCloseSettingsCommand(input)) {
      final closedName = _onCloseApp();
      _addCloseMessage(
        closedName,
        intent: 'Close',
        pendingIndex: pendingIndex,
        details: _performanceLabelOrNull(startedAt),
      );
      return true;
    }

    if (_isSettingsCommand(input)) {
      _onOpenSettings();
      _emitBotMessage(
        '설정 화면을 열었어요.',
        intent: 'Open Settings',
        pendingIndex: pendingIndex,
        details: _performanceLabelOrNull(startedAt),
      );
      return true;
    }

    return false;
  }

  Future<bool> _handleAiCommand(
    String input, {
    required int pendingIndex,
    required DateTime startedAt,
  }) async {
    final intent = await _aiService.resolveIntent(
      prompt: input,
      apps: _nluRouter.apps,
      currentContext: _contextName,
    );
    if (intent == null) {
      return false;
    }

    switch (intent.action) {
      case LauncherBotAiIntentAction.openApp:
        final app = _appById(intent.appId);
        if (app == null) return false;
        _onOpenApp(app);
        _emitBotMessage(
          '${app.name}을 실행했어요.',
          intent: 'AI Open App',
          pendingIndex: pendingIndex,
          details: _performanceLabel(startedAt),
        );
        return true;
      case LauncherBotAiIntentAction.closeApp:
        final app = _appById(intent.appId);
        if (app != null && _contextName != app.name) {
          _emitBotMessage(
            '${app.name}은 현재 열려 있지 않아요.',
            intent: 'AI Close App',
            pendingIndex: pendingIndex,
            details: _performanceLabel(startedAt),
          );
          return true;
        }
        final closedName = _onCloseApp();
        _addCloseMessage(
          closedName ?? app?.name,
          intent: 'AI Close App',
          pendingIndex: pendingIndex,
          details: _performanceLabel(startedAt),
        );
        return true;
      case LauncherBotAiIntentAction.openSettings:
        _onOpenSettings();
        _emitBotMessage(
          '설정 화면을 열었어요.',
          intent: 'AI Open Settings',
          pendingIndex: pendingIndex,
          details: _performanceLabel(startedAt),
        );
        return true;
      case LauncherBotAiIntentAction.answer:
        final answer = intent.answer?.trim();
        if (answer == null || answer.isEmpty || answer == input.trim()) {
          return false;
        }
        _emitBotMessage(
          answer,
          intent: 'AI',
          pendingIndex: pendingIndex,
          details: _performanceLabel(startedAt),
        );
        return true;
    }
  }

  String _suggestionTextWithAppName(AppManifest app, String message) {
    final text = message.trim();
    if (text.isEmpty) return '';
    final normalizedText = _normalizeForSuggestion(text);
    final normalizedName = _normalizeForSuggestion(app.name);
    final normalizedId = _normalizeForSuggestion(app.id);
    if (normalizedName.isNotEmpty && normalizedText.contains(normalizedName)) {
      return text;
    }
    if (normalizedId.isNotEmpty && normalizedText.contains(normalizedId)) {
      return text;
    }
    return '최근 ${app.name}을 자주 열었어요. 지금 실행할까요?';
  }

  String _normalizeForSuggestion(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]+'), '');
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

  void _emitBotMessage(
    String text, {
    String? intent,
    int? pendingIndex,
    String? details,
  }) {
    if (pendingIndex == null) {
      _addMessage(
        LauncherBotMessage(
          speaker: LauncherBotSpeaker.bot,
          text: text,
          timestamp: _nowLabel(),
          intent: intent,
          details: details,
        ),
      );
      return;
    }
    _messages[pendingIndex] = _messages[pendingIndex].copyWith(
      text: text,
      timestamp: _nowLabel(),
      intent: intent,
      details: details,
    );
    notifyListeners();
  }

  void _addCloseMessage(
    String? closedName, {
    String? intent,
    int? pendingIndex,
    String? details,
  }) {
    if (closedName == null || closedName == 'Launcher') {
      _emitBotMessage(
        '닫을 앱이 없어요.',
        intent: intent,
        pendingIndex: pendingIndex,
        details: details,
      );
      return;
    }
    _emitBotMessage(
      '$closedName을 닫았어요.',
      intent: intent,
      pendingIndex: pendingIndex,
      details: details,
    );
  }

  String? _performanceLabelOrNull(DateTime? startedAt) {
    if (startedAt == null) return null;
    return _performanceLabel(startedAt);
  }

  String _performanceLabel(DateTime startedAt) {
    final completedAt = DateTime.now();
    final elapsed = completedAt.difference(startedAt);
    final elapsedText = elapsed.inMilliseconds < 1000
        ? '${elapsed.inMilliseconds}ms'
        : '${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)}s';
    return '완료 ${_timeLabel(completedAt, withSeconds: true)} · $elapsedText';
  }

  void _addMessage(LauncherBotMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  String _nowLabel() {
    return _timeLabel(DateTime.now());
  }

  String _timeLabel(DateTime time, {bool withSeconds = false}) {
    final base = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (!withSeconds) return base;
    return '$base:${time.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
