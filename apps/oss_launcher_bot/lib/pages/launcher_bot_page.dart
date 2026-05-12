import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../services/gemma_chatbot_service.dart';
import '../widgets/chat_panel.dart';
import '../widgets/composer.dart';
import '../widgets/metrics_dialog.dart';
import '../widgets/quick_prompt_bar.dart';
import '../widgets/virtual_keyboard.dart';

class LauncherBotPage extends StatefulWidget {
  const LauncherBotPage({super.key});

  @override
  State<LauncherBotPage> createState() => _LauncherBotPageState();
}

class _LauncherBotPageState extends State<LauncherBotPage> {
  final TextEditingController _messageController = TextEditingController(
    text: '내비게이션 앱 실행해줘',
  );
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  final GemmaChatbotService _chatbotService = GemmaChatbotService();

  final List<ChatMessage> _messages = [
    ChatMessage(
      speaker: ChatSpeaker.bot,
      title: 'LAUNCHER BOT',
      message: '무엇을 도와드릴까요? 앱 실행, 길안내, 즐겨찾기 이동을 빠르게 처리할 수 있어요.',
      timestamp: '09:41',
      intent: 'Ready',
    ),
    ChatMessage(
      speaker: ChatSpeaker.user,
      title: 'DRIVER',
      message: '지도 앱 열고 집까지 경로 보여줘.',
      timestamp: '09:42',
    ),
    ChatMessage(
      speaker: ChatSpeaker.bot,
      title: 'LAUNCHER BOT',
      message: '내비게이션 앱을 실행하고 최근 목적지에서 집 경로를 이어서 보여드릴게요.',
      timestamp: '09:42',
      intent: 'Launch Intent',
    ),
  ];

  final List<QuickPrompt> _quickPrompts = const [
    QuickPrompt(
      label: '내비 실행',
      command: '내비게이션 앱 실행해줘',
      icon: Icons.navigation_outlined,
    ),
    QuickPrompt(
      label: '뮤직 재생',
      command: '뮤직 앱 실행해줘',
      icon: Icons.music_note_outlined,
    ),
    QuickPrompt(
      label: '전화 열기',
      command: '전화 앱 실행해줘',
      icon: Icons.call_outlined,
    ),
  ];

  final List<String> _suggestions = const [
    '집으로 가는 길 보여줘',
    '뮤직 앱 실행해줘',
    '최근 연락처 열어줘',
  ];

  bool _isKeyboardVisible = false;
  bool _isGenerating = false;
  Timer? _generatingTimer;
  int? _generatingMessageIndex;
  int _generatingDotCount = 1;
  Timer? _recognizingTimer;
  int? _recognizingMessageIndex;
  int _recognizingDotCount = 1;

  static const String _sampleVoiceAssetPath = 'assets/audio/1_0005_16k.wav';

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _chatScrollController.dispose();
    _generatingTimer?.cancel();
    _recognizingTimer?.cancel();
    _chatbotService.dispose();
    super.dispose();
  }

  void _showKeyboard() {
    setState(() {
      _isKeyboardVisible = true;
    });
    _messageFocusNode.requestFocus();
    _moveCursorToEnd();
  }

  void _hideKeyboard() {
    setState(() {
      _isKeyboardVisible = false;
    });
    _messageFocusNode.unfocus();
  }

  void _replaceInput(String text) {
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 330),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _insertText(String value, {int replaceBackCount = 0}) {
    final selection = _messageController.selection;
    final text = _messageController.text;
    final selectionStart = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final start = selectionStart == end
        ? (selectionStart - replaceBackCount).clamp(0, text.length).toInt()
        : selectionStart;
    final nextText = text.replaceRange(start, end, value);
    final nextOffset = start + value.length;

    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }

  void _backspace() {
    final selection = _messageController.selection;
    final text = _messageController.text;

    if (text.isEmpty) {
      return;
    }

    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    if (start != end) {
      final nextText = text.replaceRange(start, end, '');
      _messageController.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }

    if (start <= 0) {
      return;
    }

    final nextText = text.replaceRange(start - 1, start, '');
    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start - 1),
    );
  }

  void _moveCursorToEnd() {
    final textLength = _messageController.text.length;
    _messageController.selection = TextSelection.collapsed(offset: textLength);
  }

  String get _generatingMessage => '답변 생성중${'.' * _generatingDotCount}';
  String get _recognizingMessage => '음성 인식중${'.' * _recognizingDotCount}';

  void _startGeneratingIndicator(int messageIndex) {
    _generatingTimer?.cancel();
    _generatingMessageIndex = messageIndex;
    _generatingDotCount = 1;

    _generatingTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted || !_isGenerating || _generatingMessageIndex == null) {
        return;
      }

      setState(() {
        _generatingDotCount = _generatingDotCount % 3 + 1;
        final index = _generatingMessageIndex!;
        if (index >= 0 && index < _messages.length) {
          final current = _messages[index];
          _messages[index] = ChatMessage(
            speaker: current.speaker,
            title: current.title,
            message: _generatingMessage,
            timestamp: current.timestamp,
            intent: current.intent,
          );
        }
      });
      _scrollChatToBottom();
    });
  }

  void _stopGeneratingIndicator() {
    _generatingTimer?.cancel();
    _generatingTimer = null;
    _generatingMessageIndex = null;
  }

  void _startRecognizingIndicator(int messageIndex) {
    _recognizingTimer?.cancel();
    _recognizingMessageIndex = messageIndex;
    _recognizingDotCount = 1;

    _recognizingTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted || !_isGenerating || _recognizingMessageIndex == null) {
        return;
      }

      setState(() {
        _recognizingDotCount = _recognizingDotCount % 3 + 1;
        final index = _recognizingMessageIndex!;
        if (index >= 0 && index < _messages.length) {
          final current = _messages[index];
          _messages[index] = ChatMessage(
            speaker: current.speaker,
            title: current.title,
            message: _recognizingMessage,
            timestamp: current.timestamp,
            intent: current.intent,
          );
        }
      });
      _scrollChatToBottom();
    });
  }

  void _stopRecognizingIndicator() {
    _recognizingTimer?.cancel();
    _recognizingTimer = null;
    _recognizingMessageIndex = null;
  }

  Future<void> _submitMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isGenerating) {
      return;
    }

    final userIndex = _messages.length;
    final pendingIndex = userIndex + 1;
    setState(() {
      _isGenerating = true;
      _messages.add(
        ChatMessage(
          speaker: ChatSpeaker.user,
          title: 'DRIVER',
          message: text,
          timestamp: _nowLabel(),
        ),
      );
      _messages.add(
        ChatMessage(
          speaker: ChatSpeaker.bot,
          title: 'LAUNCHER BOT',
          message: _generatingMessage,
          timestamp: _nowLabel(),
          intent: 'Generating',
        ),
      );
    });
    _startGeneratingIndicator(pendingIndex);
    _scrollChatToBottom();

    _replaceInput('');
    _hideKeyboard();

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }

      final response = await _chatbotService.generate(text);
      if (!mounted) {
        return;
      }

      setState(() {
        _stopGeneratingIndicator();
        _messages[pendingIndex] = ChatMessage(
          speaker: ChatSpeaker.bot,
          title: 'LAUNCHER BOT',
          message: response.trim().isEmpty
              ? '응답 내용이 비어 있습니다.'
              : response.trim(),
          timestamp: _nowLabel(),
          intent: 'Gemma',
        );
      });
      _scrollChatToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _stopGeneratingIndicator();
        _messages[pendingIndex] = ChatMessage(
          speaker: ChatSpeaker.bot,
          title: 'LAUNCHER BOT',
          message: 'Gemma 모델 응답 생성에 실패했습니다. $error',
          timestamp: _nowLabel(),
          intent: 'Error',
        );
      });
      _scrollChatToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _stopGeneratingIndicator();
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _submitSampleAudio() async {
    if (_isGenerating) {
      return;
    }

    final userIndex = _messages.length;
    final pendingIndex = userIndex + 1;
    setState(() {
      _isGenerating = true;
      _messages.add(
        ChatMessage(
          speaker: ChatSpeaker.user,
          title: 'DRIVER',
          message: _recognizingMessage,
          timestamp: _nowLabel(),
        ),
      );
      _messages.add(
        ChatMessage(
          speaker: ChatSpeaker.bot,
          title: 'LAUNCHER BOT',
          message: _generatingMessage,
          timestamp: _nowLabel(),
          intent: 'Audio',
        ),
      );
    });
    _startRecognizingIndicator(userIndex);
    _startGeneratingIndicator(pendingIndex);
    _scrollChatToBottom();
    _hideKeyboard();

    try {
      final audio = await _loadSampleAudio();
      final hasAudio = await _chatbotService.hasAudio();
      if (!hasAudio) {
        throw const GemmaChatbotException(
          '현재 LlamaCppProvider가 오디오 입력을 지원하지 않습니다. mmproj 설정을 확인해 주세요.',
        );
      }

      final response = await _chatbotService.generateAudio(
        prompt:
            '이 오디오를 한국어 텍스트로 정확히 받아쓰기해줘. '
            '명령이면 의도도 짧게 정리해줘. '
            '특수 토큰이나 turn marker는 출력하지 마.',
        pcm: audio.pcm,
        sampleRate: audio.sampleRate,
        channels: audio.channels,
      );
      if (!mounted) {
        return;
      }

      final recognizedText = response.trim();
      if (recognizedText.isEmpty) {
        setState(() {
          _stopRecognizingIndicator();
          _stopGeneratingIndicator();
          _messages[userIndex] = ChatMessage(
            speaker: ChatSpeaker.user,
            title: 'DRIVER',
            message: '음성 인식 결과가 비어 있습니다.',
            timestamp: _messages[userIndex].timestamp,
          );
          _messages[pendingIndex] = ChatMessage(
            speaker: ChatSpeaker.bot,
            title: 'LAUNCHER BOT',
            message: '음성 내용을 인식하지 못했습니다.',
            timestamp: _nowLabel(),
            intent: 'Gemma Audio',
          );
        });
        _scrollChatToBottom();
        return;
      }

      setState(() {
        _stopRecognizingIndicator();
        _messages[userIndex] = ChatMessage(
          speaker: ChatSpeaker.user,
          title: 'DRIVER',
          message: recognizedText,
          timestamp: _messages[userIndex].timestamp,
        );
      });
      _scrollChatToBottom();

      final answer = await _chatbotService.generate(recognizedText);
      if (!mounted) {
        return;
      }

      setState(() {
        _stopGeneratingIndicator();
        _messages[pendingIndex] = ChatMessage(
          speaker: ChatSpeaker.bot,
          title: 'LAUNCHER BOT',
          message: answer.trim().isEmpty ? '응답 내용이 비어 있습니다.' : answer.trim(),
          timestamp: _nowLabel(),
          intent: 'Gemma',
        );
      });
      _scrollChatToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _stopRecognizingIndicator();
        _stopGeneratingIndicator();
        _messages[pendingIndex] = ChatMessage(
          speaker: ChatSpeaker.bot,
          title: 'LAUNCHER BOT',
          message: 'Gemma 오디오 입력 처리에 실패했습니다. $error',
          timestamp: _nowLabel(),
          intent: 'Error',
        );
      });
      _scrollChatToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _stopGeneratingIndicator();
          _stopRecognizingIndicator();
          _isGenerating = false;
        });
      }
    }
  }

  Future<_PcmAudio> _loadSampleAudio() async {
    final data = await rootBundle.load(_sampleVoiceAssetPath);
    final audio = _decodeWavPcm(data);
    debugPrint(
      '[LauncherBot] sample audio loaded: '
      'asset=$_sampleVoiceAssetPath, '
      'samples=${audio.pcm.length}, '
      'sampleRate=${audio.sampleRate}, '
      'channels=${audio.channels}, '
      'durationMs=${(audio.pcm.length / audio.sampleRate * 1000).toStringAsFixed(1)}',
    );
    return audio;
  }

  String _nowLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showMetrics() {
    showDialog<void>(
      context: context,
      builder: (context) =>
          MetricsDialog(loadModelMetrics: _chatbotService.metricsIfReady),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final compact = mediaQuery.size.width < 900;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _hideKeyboard,
        child: ColoredBox(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 330),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 24,
                  compact ? 12 : 16,
                  compact ? 16 : 24,
                  16,
                ),
                child: Column(
                  children: [
                    QuickPromptBar(
                      compact: compact,
                      prompts: _quickPrompts,
                      onMetricsTap: _showMetrics,
                      onPromptTap: (prompt) {
                        _replaceInput(prompt.command);
                        _showKeyboard();
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ChatPanel(
                        controller: _chatScrollController,
                        messages: _messages,
                        suggestions: _suggestions,
                        onSuggestionTap: (suggestion) {
                          _replaceInput(suggestion);
                          _showKeyboard();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {},
                      child: Composer(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        onFieldTap: _showKeyboard,
                        onSend: _submitMessage,
                        onVoiceTap: _submitSampleAudio,
                      ),
                    ),
                    if (_isKeyboardVisible) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {},
                        child: VirtualKeyboard(
                          onTextInput: _insertText,
                          onBackspace: _backspace,
                          onSpace: () => _insertText(' '),
                          onHide: _hideKeyboard,
                          onSubmit: _submitMessage,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PcmAudio {
  const _PcmAudio({
    required this.pcm,
    required this.sampleRate,
    required this.channels,
  });

  final Float32List pcm;
  final int sampleRate;
  final int channels;
}

_PcmAudio _decodeWavPcm(ByteData data) {
  String fourCc(int offset) {
    return String.fromCharCodes([
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ]);
  }

  if (data.lengthInBytes < 44 || fourCc(0) != 'RIFF' || fourCc(8) != 'WAVE') {
    throw const FormatException('지원하지 않는 WAV 파일입니다.');
  }

  int? audioFormat;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  int? dataOffset;
  int? dataSize;

  var offset = 12;
  while (offset + 8 <= data.lengthInBytes) {
    final chunkId = fourCc(offset);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkDataOffset = offset + 8;

    if (chunkId == 'fmt ') {
      audioFormat = data.getUint16(chunkDataOffset, Endian.little);
      channels = data.getUint16(chunkDataOffset + 2, Endian.little);
      sampleRate = data.getUint32(chunkDataOffset + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkDataOffset + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkDataOffset;
      dataSize = chunkSize;
    }

    offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  if (audioFormat == null ||
      channels == null ||
      sampleRate == null ||
      bitsPerSample == null ||
      dataOffset == null ||
      dataSize == null) {
    throw const FormatException('WAV fmt/data chunk를 찾을 수 없습니다.');
  }

  if (audioFormat != 1 || bitsPerSample != 16) {
    throw FormatException(
      'PCM 16-bit WAV만 지원합니다. format=$audioFormat bits=$bitsPerSample',
    );
  }

  final frameCount = dataSize ~/ (channels * 2);
  final pcm = Float32List(frameCount);
  var cursor = dataOffset;
  for (var frame = 0; frame < frameCount; frame += 1) {
    var sum = 0.0;
    for (var channel = 0; channel < channels; channel += 1) {
      sum += data.getInt16(cursor, Endian.little) / 32768.0;
      cursor += 2;
    }
    pcm[frame] = sum / channels;
  }

  return _PcmAudio(pcm: pcm, sampleRate: sampleRate, channels: 1);
}
