import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

typedef _ChatbotCreateNative = Pointer<Void> Function(Pointer<Int8> configPath);
typedef _ChatbotCreateDart = Pointer<Void> Function(Pointer<Int8> configPath);

typedef _ChatbotGenerateNative =
    Pointer<Int8> Function(Pointer<Void> handle, Pointer<Int8> prompt);
typedef _ChatbotGenerateDart =
    Pointer<Int8> Function(Pointer<Void> handle, Pointer<Int8> prompt);

typedef _ChatbotHasAudioNative = Int32 Function(Pointer<Void> handle);
typedef _ChatbotHasAudioDart = int Function(Pointer<Void> handle);

typedef _ChatbotGenerateAudioNative =
    Pointer<Int8> Function(
      Pointer<Void> handle,
      Pointer<Int8> prompt,
      Pointer<Float> pcm,
      Int32 sampleCount,
      Int32 sampleRate,
      Int32 channels,
    );
typedef _ChatbotGenerateAudioDart =
    Pointer<Int8> Function(
      Pointer<Void> handle,
      Pointer<Int8> prompt,
      Pointer<Float> pcm,
      int sampleCount,
      int sampleRate,
      int channels,
    );

typedef _ChatbotGenerateWithContextsNative =
    Pointer<Int8> Function(
      Pointer<Void> handle,
      Pointer<Int8> prompt,
      Pointer<Pointer<Int8>> contexts,
      Int32 contextCount,
    );
typedef _ChatbotGenerateWithContextsDart =
    Pointer<Int8> Function(
      Pointer<Void> handle,
      Pointer<Int8> prompt,
      Pointer<Pointer<Int8>> contexts,
      int contextCount,
    );

typedef _ChatbotFreeStringNative = Void Function(Pointer<Int8> value);
typedef _ChatbotFreeStringDart = void Function(Pointer<Int8> value);

typedef _ChatbotDestroyNative = Void Function(Pointer<Void> handle);
typedef _ChatbotDestroyDart = void Function(Pointer<Void> handle);

typedef _ChatbotLastTokensNative = Int32 Function(Pointer<Void> handle);
typedef _ChatbotLastTokensDart = int Function(Pointer<Void> handle);

typedef _ChatbotLastTimeNative = Float Function(Pointer<Void> handle);
typedef _ChatbotLastTimeDart = double Function(Pointer<Void> handle);

typedef _MallocNative = Pointer<Void> Function(IntPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);

typedef _FreeNative = Void Function(Pointer<Void> pointer);
typedef _FreeDart = void Function(Pointer<Void> pointer);

class GemmaChatbotService {
  GemmaChatbotService();

  _ChatbotWorker? _worker;
  bool _initializing = false;

  Future<String> generate(String prompt) async {
    final worker = await _ensureWorker();
    return worker.generate(prompt);
  }

  Future<bool> hasAudio() async {
    final worker = await _ensureWorker();
    return worker.hasAudio();
  }

  Future<String> generateAudio({
    required String prompt,
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) async {
    final worker = await _ensureWorker();
    return worker.generateAudio(
      prompt: prompt,
      pcm: pcm,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  Future<String> generateWithContexts(
    String prompt,
    List<String> contexts,
  ) async {
    final worker = await _ensureWorker();
    return worker.generateWithContexts(prompt, contexts);
  }

  Future<GemmaModelMetrics> metrics() async {
    final worker = await _ensureWorker();
    return worker.metrics();
  }

  Future<GemmaModelMetrics?> metricsIfReady() async {
    return _worker?.metrics();
  }

  Future<_ChatbotWorker> _ensureWorker() async {
    final cached = _worker;
    if (cached != null) {
      return cached;
    }

    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final initialized = _worker;
      if (initialized != null) {
        return initialized;
      }
    }

    _initializing = true;
    try {
      final bundleRoot = _resolveBundleRoot();
      final configPath = await _writeResolvedConfig(bundleRoot);
      final worker = await _ChatbotWorker.start(
        configPath,
        _resolveBridgeLibraryPath(bundleRoot),
      );
      _worker = worker;
      return worker;
    } finally {
      _initializing = false;
    }
  }

  Future<String> _writeResolvedConfig(Directory bundleRoot) async {
    final configPath = _firstExistingPath(_configPathCandidates(bundleRoot));

    if (configPath == null) {
      throw GemmaChatbotException(
        'Gemma 설정 파일을 찾을 수 없습니다: assets/config/llm_config_gemma.json '
        '(bundle=${bundleRoot.path})',
      );
    }

    final configFile = File(configPath);
    final config = jsonDecode(await configFile.readAsString());
    if (config is! Map<String, dynamic>) {
      throw const GemmaChatbotException('Gemma 설정 JSON 형식이 올바르지 않습니다.');
    }

    final rawModelPath = config['model_path'];
    if (rawModelPath is! String || rawModelPath.isEmpty) {
      throw const GemmaChatbotException('Gemma 설정에 model_path가 없습니다.');
    }

    config['model_path'] = _resolveModelPath(rawModelPath, bundleRoot);
    String? resolvedMmprojPath;
    for (final key in [
      'mmproj_path',
      'mm_projector_path',
      'multimodal_projector_path',
      'llamacpp_mmproj_path',
    ]) {
      final rawPath = config[key];
      if (rawPath is String && rawPath.isNotEmpty) {
        resolvedMmprojPath = _resolveModelPath(rawPath, bundleRoot);
        config[key] = resolvedMmprojPath;
      }
    }
    final llamacpp = config['llamacpp'];
    if (llamacpp is Map<String, dynamic>) {
      for (final key in [
        'mmproj_path',
        'mm_projector_path',
        'multimodal_projector_path',
      ]) {
        final rawPath = llamacpp[key];
        if (rawPath is String && rawPath.isNotEmpty) {
          resolvedMmprojPath = _resolveModelPath(rawPath, bundleRoot);
          llamacpp[key] = resolvedMmprojPath;
        }
      }

      if (resolvedMmprojPath != null) {
        llamacpp['mmproj_path'] = resolvedMmprojPath;
        llamacpp['mm_projector_path'] = resolvedMmprojPath;
      }
    }
    if (resolvedMmprojPath != null) {
      config['mmproj_path'] = resolvedMmprojPath;
      config['llamacpp_mmproj_path'] = resolvedMmprojPath;
    }

    final resolvedConfig = File(
      '${Directory.systemTemp.path}/oss_launcher_bot_llm_config_gemma.json',
    );
    await resolvedConfig.writeAsString(jsonEncode(config));
    return resolvedConfig.path;
  }

  String _resolveModelPath(String rawModelPath, Directory bundleRoot) {
    if (rawModelPath.startsWith('/')) {
      return rawModelPath;
    }

    final resolved = _firstExistingPath([
      '${bundleRoot.path}/data/$rawModelPath',
      '${bundleRoot.path}/data/flutter_assets/$rawModelPath',
      '${Directory.current.path}/$rawModelPath',
    ]);

    return resolved ?? '${bundleRoot.path}/data/$rawModelPath';
  }

  String _resolveBridgeLibraryPath(Directory bundleRoot) {
    final bridgePath = _firstExistingPath(_bridgePathCandidates(bundleRoot));

    if (bridgePath == null) {
      throw GemmaChatbotException(
        'libchatbot_bridge.so를 찾을 수 없습니다. Obigo Oasis SDK를 추가한 뒤 Linux 앱을 다시 빌드해 주세요. '
        '(bundle=${bundleRoot.path})',
      );
    }

    return bridgePath;
  }

  List<String> _configPathCandidates(Directory bundleRoot) {
    return [
      '${bundleRoot.path}/data/flutter_assets/assets/config/llm_config_gemma.json',
      '${bundleRoot.path}/flutter_assets/assets/config/llm_config_gemma.json',
      '${bundleRoot.path}/assets/config/llm_config_gemma.json',
      '${Directory.current.path}/assets/config/llm_config_gemma.json',
    ];
  }

  List<String> _bridgePathCandidates(Directory bundleRoot) {
    return [
      '${bundleRoot.path}/lib/libchatbot_bridge.so',
      '${Directory.current.path}/build/linux/x64/debug/bundle/lib/libchatbot_bridge.so',
      '${Directory.current.path}/build/linux/x64/release/bundle/lib/libchatbot_bridge.so',
    ];
  }

  Directory _resolveBundleRoot() {
    for (final candidate in _bundleRootCandidates()) {
      final hasConfig =
          _firstExistingPath(_configPathCandidates(candidate)) != null;
      final hasBridge =
          _firstExistingPath(_bridgePathCandidates(candidate)) != null;
      if (hasConfig && hasBridge) {
        return candidate;
      }
    }

    for (final candidate in _bundleRootCandidates()) {
      if (_firstExistingPath(_configPathCandidates(candidate)) != null) {
        return candidate;
      }
    }

    return _executableBundleRoot;
  }

  List<Directory> _bundleRootCandidates() {
    final candidates = <Directory>[];

    void add(String? path) {
      if (path == null || path.isEmpty) {
        return;
      }
      final normalized = path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;
      if (normalized.isEmpty) {
        return;
      }
      if (!candidates.any((candidate) => candidate.path == normalized)) {
        candidates.add(Directory(normalized));
      }
    }

    add(Platform.environment['BUNDLE_PATH']);
    add(Platform.environment['FLUTTER_BUNDLE_PATH']);
    add(_executableBundleRoot.path);
    add(Directory.current.path);
    add('${Directory.current.path}/build/linux/x64/debug/bundle');
    add('${Directory.current.path}/build/linux/x64/release/bundle');

    final appShareRoot = Directory('/usr/share/flutter/oss_launcher_bot');
    if (appShareRoot.existsSync()) {
      for (final versionDir in appShareRoot.listSync().whereType<Directory>()) {
        add('${versionDir.path}/release');
        add('${versionDir.path}/profile');
        add('${versionDir.path}/debug');
      }
    }

    return candidates;
  }

  String? _firstExistingPath(List<String> candidates) {
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  Directory get _executableBundleRoot {
    final executable = File(Platform.resolvedExecutable);
    return executable.parent;
  }

  void dispose() {
    _worker?.dispose();
    _worker = null;
  }
}

class GemmaChatbotException implements Exception {
  const GemmaChatbotException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GemmaModelMetrics {
  const GemmaModelMetrics({
    required this.tokens,
    required this.generationTimeMs,
    required this.firstTokenTimeMs,
  });

  final int tokens;
  final double generationTimeMs;
  final double firstTokenTimeMs;

  double get tokensPerSecond {
    if (tokens <= 0 || generationTimeMs <= 0) {
      return 0;
    }
    return tokens / (generationTimeMs / 1000);
  }
}

class _ChatbotWorker {
  _ChatbotWorker._(
    this._isolate,
    this._receivePort,
    this._subscription,
    this._sendPort,
  );

  final Isolate _isolate;
  final ReceivePort _receivePort;
  final StreamSubscription<dynamic> _subscription;
  final SendPort _sendPort;
  final Map<int, Completer<String>> _pending = {};
  final Map<int, Completer<bool>> _pendingBool = {};
  final Map<int, Completer<GemmaModelMetrics>> _pendingMetrics = {};
  int _nextRequestId = 1;
  bool _disposed = false;

  static Future<_ChatbotWorker> start(
    String configPath,
    String libraryPath,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn<List<Object?>>(
      _chatbotWorkerMain,
      [receivePort.sendPort, configPath, libraryPath],
      debugName: 'GemmaChatbotWorker',
      errorsAreFatal: true,
    );

    final ready = Completer<_ChatbotWorker>();
    _ChatbotWorker? worker;
    late final StreamSubscription<dynamic> subscription;

    subscription = receivePort.listen((message) {
      if (message is! List<Object?> || message.isEmpty) {
        return;
      }

      final command = message[0];
      if (command == 'ready') {
        worker = _ChatbotWorker._(
          isolate,
          receivePort,
          subscription,
          message[1]! as SendPort,
        );
        ready.complete(worker);
        return;
      }

      if (command == 'startupError') {
        final error = message.length > 1 ? message[1].toString() : '알 수 없는 오류';
        subscription.cancel();
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
        ready.completeError(GemmaChatbotException(error));
        return;
      }

      worker?._handleMessage(message);
    });

    return ready.future;
  }

  Future<String> generate(String prompt) {
    if (_disposed) {
      return Future<String>.error(
        const GemmaChatbotException('Gemma worker가 이미 종료되었습니다.'),
      );
    }

    final requestId = _nextRequestId;
    _nextRequestId += 1;

    final completer = Completer<String>();
    _pending[requestId] = completer;
    _sendPort.send(['generate', requestId, prompt]);
    return completer.future;
  }

  Future<bool> hasAudio() {
    if (_disposed) {
      return Future<bool>.error(
        const GemmaChatbotException('Gemma worker가 이미 종료되었습니다.'),
      );
    }

    final requestId = _nextRequestId;
    _nextRequestId += 1;

    final completer = Completer<bool>();
    _pendingBool[requestId] = completer;
    _sendPort.send(['hasAudio', requestId]);
    return completer.future;
  }

  Future<String> generateAudio({
    required String prompt,
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) {
    if (_disposed) {
      return Future<String>.error(
        const GemmaChatbotException('Gemma worker가 이미 종료되었습니다.'),
      );
    }

    final requestId = _nextRequestId;
    _nextRequestId += 1;

    final completer = Completer<String>();
    _pending[requestId] = completer;
    _sendPort.send([
      'generateAudio',
      requestId,
      prompt,
      TransferableTypedData.fromList([pcm]),
      sampleRate,
      channels,
    ]);
    return completer.future;
  }

  Future<String> generateWithContexts(String prompt, List<String> contexts) {
    if (_disposed) {
      return Future<String>.error(
        const GemmaChatbotException('Gemma worker가 이미 종료되었습니다.'),
      );
    }

    final requestId = _nextRequestId;
    _nextRequestId += 1;

    final completer = Completer<String>();
    _pending[requestId] = completer;
    _sendPort.send(['generateWithContexts', requestId, prompt, contexts]);
    return completer.future;
  }

  Future<GemmaModelMetrics> metrics() {
    if (_disposed) {
      return Future<GemmaModelMetrics>.error(
        const GemmaChatbotException('Gemma worker가 이미 종료되었습니다.'),
      );
    }

    final requestId = _nextRequestId;
    _nextRequestId += 1;

    final completer = Completer<GemmaModelMetrics>();
    _pendingMetrics[requestId] = completer;
    _sendPort.send(['metrics', requestId]);
    return completer.future;
  }

  void _handleMessage(List<Object?> message) {
    final command = message[0];
    if (command == 'ok') {
      final requestId = message[1]! as int;
      final response = message[2]?.toString() ?? '';
      _pending.remove(requestId)?.complete(response);
      return;
    }

    if (command == 'error') {
      final requestId = message[1]! as int;
      final error = message.length > 2 ? message[2].toString() : '알 수 없는 오류';
      _pending.remove(requestId)?.completeError(GemmaChatbotException(error));
      return;
    }

    if (command == 'bool') {
      final requestId = message[1]! as int;
      final value = message[2] == true;
      _pendingBool.remove(requestId)?.complete(value);
      return;
    }

    if (command == 'fatal') {
      final error = message.length > 1 ? message[1].toString() : '알 수 없는 오류';
      _completePendingWithError(GemmaChatbotException(error));
      _completePendingBoolWithError(GemmaChatbotException(error));
      _completePendingMetricsWithError(GemmaChatbotException(error));
      return;
    }

    if (command == 'metrics') {
      final requestId = message[1]! as int;
      final tokens = message[2]! as int;
      final generationTimeMs = message[3]! as double;
      final firstTokenTimeMs = message[4]! as double;
      _pendingMetrics
          .remove(requestId)
          ?.complete(
            GemmaModelMetrics(
              tokens: tokens,
              generationTimeMs: generationTimeMs,
              firstTokenTimeMs: firstTokenTimeMs,
            ),
          );
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _sendPort.send(['dispose']);
    _completePendingWithError(
      const GemmaChatbotException('Gemma worker가 종료되었습니다.'),
    );
    _completePendingBoolWithError(
      const GemmaChatbotException('Gemma worker가 종료되었습니다.'),
    );
    _completePendingMetricsWithError(
      const GemmaChatbotException('Gemma worker가 종료되었습니다.'),
    );
    _subscription.cancel();
    _receivePort.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  void _completePendingWithError(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
  }

  void _completePendingBoolWithError(Object error) {
    for (final completer in _pendingBool.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingBool.clear();
  }

  void _completePendingMetricsWithError(Object error) {
    for (final completer in _pendingMetrics.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pendingMetrics.clear();
  }
}

void _chatbotWorkerMain(List<Object?> args) {
  final mainPort = args[0]! as SendPort;
  final configPath = args[1]! as String;
  final libraryPath = args[2]! as String;
  final commandPort = ReceivePort();

  late final _NativeChatbot chatbot;
  try {
    chatbot = _NativeChatbot(configPath, libraryPath);
  } catch (error, stackTrace) {
    mainPort.send(['startupError', '$error\n$stackTrace']);
    commandPort.close();
    return;
  }

  mainPort.send(['ready', commandPort.sendPort]);

  commandPort.listen((message) {
    if (message is! List<Object?> || message.isEmpty) {
      return;
    }

    final command = message[0];
    if (command == 'generate') {
      final requestId = message[1]! as int;
      final prompt = message[2]! as String;

      try {
        final response = chatbot.generate(prompt);
        mainPort.send(['ok', requestId, response]);
      } catch (error, stackTrace) {
        mainPort.send(['error', requestId, '$error\n$stackTrace']);
      }
      return;
    }

    if (command == 'hasAudio') {
      final requestId = message[1]! as int;
      try {
        mainPort.send(['bool', requestId, chatbot.hasAudio()]);
      } catch (error, stackTrace) {
        mainPort.send(['error', requestId, '$error\n$stackTrace']);
      }
      return;
    }

    if (command == 'generateAudio') {
      final requestId = message[1]! as int;
      final prompt = message[2]! as String;
      final audioData = message[3]! as TransferableTypedData;
      final sampleRate = message[4]! as int;
      final channels = message[5]! as int;

      try {
        final pcm = audioData.materialize().asFloat32List();
        final response = chatbot.generateAudio(
          prompt: prompt,
          pcm: pcm,
          sampleRate: sampleRate,
          channels: channels,
        );
        mainPort.send(['ok', requestId, response]);
      } catch (error, stackTrace) {
        mainPort.send(['error', requestId, '$error\n$stackTrace']);
      }
      return;
    }

    if (command == 'generateWithContexts') {
      final requestId = message[1]! as int;
      final prompt = message[2]! as String;
      final rawContexts = message[3]! as List<Object?>;
      final contexts = rawContexts.map((value) => value.toString()).toList();

      try {
        final response = chatbot.generateWithContexts(prompt, contexts);
        mainPort.send(['ok', requestId, response]);
      } catch (error, stackTrace) {
        mainPort.send(['error', requestId, '$error\n$stackTrace']);
      }
      return;
    }

    if (command == 'metrics') {
      final requestId = message[1]! as int;
      final metrics = chatbot.metrics();
      mainPort.send([
        'metrics',
        requestId,
        metrics.tokens,
        metrics.generationTimeMs,
        metrics.firstTokenTimeMs,
      ]);
      return;
    }

    if (command == 'dispose') {
      chatbot.dispose();
      commandPort.close();
    }
  });
}

class _NativeChatbot {
  _NativeChatbot(String configPath, String libraryPath) {
    _library = DynamicLibrary.open(libraryPath);
    _libc = DynamicLibrary.open('libc.so.6');

    _malloc = _libc.lookupFunction<_MallocNative, _MallocDart>('malloc');
    _free = _libc.lookupFunction<_FreeNative, _FreeDart>('free');
    _create = _library.lookupFunction<_ChatbotCreateNative, _ChatbotCreateDart>(
      'chatbot_create',
    );
    _generate = _library
        .lookupFunction<_ChatbotGenerateNative, _ChatbotGenerateDart>(
          'chatbot_generate',
        );
    _hasAudio = _library
        .lookupFunction<_ChatbotHasAudioNative, _ChatbotHasAudioDart>(
          'chatbot_has_audio',
        );
    _generateAudio = _library
        .lookupFunction<_ChatbotGenerateAudioNative, _ChatbotGenerateAudioDart>(
          'chatbot_generate_audio_f32',
        );
    _generateWithContexts = _library
        .lookupFunction<
          _ChatbotGenerateWithContextsNative,
          _ChatbotGenerateWithContextsDart
        >('chatbot_generate_with_contexts');
    _freeString = _library
        .lookupFunction<_ChatbotFreeStringNative, _ChatbotFreeStringDart>(
          'chatbot_free_string',
        );
    _destroy = _library
        .lookupFunction<_ChatbotDestroyNative, _ChatbotDestroyDart>(
          'chatbot_destroy',
        );
    _lastTokens = _library
        .lookupFunction<_ChatbotLastTokensNative, _ChatbotLastTokensDart>(
          'chatbot_last_tokens',
        );
    _lastGenerationTime = _library
        .lookupFunction<_ChatbotLastTimeNative, _ChatbotLastTimeDart>(
          'chatbot_last_generation_time_ms',
        );
    _lastFirstTokenTime = _library
        .lookupFunction<_ChatbotLastTimeNative, _ChatbotLastTimeDart>(
          'chatbot_last_first_token_time_ms',
        );

    final configPathPointer = _toNativeUtf8(configPath);
    try {
      _handle = _create(configPathPointer);
    } finally {
      _free(configPathPointer.cast<Void>());
    }

    if (_handle == nullptr) {
      throw GemmaChatbotException('Gemma 모델 초기화에 실패했습니다: $configPath');
    }
  }

  late final DynamicLibrary _library;
  late final DynamicLibrary _libc;
  late final _MallocDart _malloc;
  late final _FreeDart _free;
  late final _ChatbotCreateDart _create;
  late final _ChatbotGenerateDart _generate;
  late final _ChatbotHasAudioDart _hasAudio;
  late final _ChatbotGenerateAudioDart _generateAudio;
  late final _ChatbotGenerateWithContextsDart _generateWithContexts;
  late final _ChatbotFreeStringDart _freeString;
  late final _ChatbotDestroyDart _destroy;
  late final _ChatbotLastTokensDart _lastTokens;
  late final _ChatbotLastTimeDart _lastGenerationTime;
  late final _ChatbotLastTimeDart _lastFirstTokenTime;
  Pointer<Void> _handle = nullptr;

  String generate(String prompt) {
    final promptPointer = _toNativeUtf8(prompt);
    Pointer<Int8> responsePointer = nullptr;

    try {
      responsePointer = _generate(_handle, promptPointer);
      if (responsePointer == nullptr) {
        throw const GemmaChatbotException('Gemma 응답 생성에 실패했습니다.');
      }
      return _fromNativeUtf8(responsePointer);
    } finally {
      _free(promptPointer.cast<Void>());
      if (responsePointer != nullptr) {
        _freeString(responsePointer);
      }
    }
  }

  bool hasAudio() {
    return _hasAudio(_handle) != 0;
  }

  String generateAudio({
    required String prompt,
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) {
    final promptPointer = _toNativeUtf8(prompt);
    final pcmPointer = _malloc(pcm.length * sizeOf<Float>()).cast<Float>();
    if (pcmPointer == nullptr) {
      _free(promptPointer.cast<Void>());
      throw const GemmaChatbotException('native 오디오 메모리 할당에 실패했습니다.');
    }

    for (var i = 0; i < pcm.length; i += 1) {
      pcmPointer[i] = pcm[i];
    }

    Pointer<Int8> responsePointer = nullptr;
    try {
      responsePointer = _generateAudio(
        _handle,
        promptPointer,
        pcmPointer,
        pcm.length,
        sampleRate,
        channels,
      );
      if (responsePointer == nullptr) {
        throw const GemmaChatbotException('Gemma 오디오 입력 응답 생성에 실패했습니다.');
      }
      return _fromNativeUtf8(responsePointer);
    } finally {
      _free(promptPointer.cast<Void>());
      _free(pcmPointer.cast<Void>());
      if (responsePointer != nullptr) {
        _freeString(responsePointer);
      }
    }
  }

  String generateWithContexts(String prompt, List<String> contexts) {
    final promptPointer = _toNativeUtf8(prompt);
    final contextPointers = <Pointer<Int8>>[];
    Pointer<Pointer<Int8>> contextsPointer = nullptr;
    Pointer<Int8> responsePointer = nullptr;

    try {
      for (final context in contexts) {
        contextPointers.add(_toNativeUtf8(context));
      }

      contextsPointer = _malloc(
        contextPointers.length * sizeOf<Pointer<Int8>>(),
      ).cast<Pointer<Int8>>();
      if (contextsPointer == nullptr && contextPointers.isNotEmpty) {
        throw const GemmaChatbotException('native context 메모리 할당에 실패했습니다.');
      }
      for (var i = 0; i < contextPointers.length; i += 1) {
        contextsPointer[i] = contextPointers[i];
      }

      responsePointer = _generateWithContexts(
        _handle,
        promptPointer,
        contextsPointer,
        contextPointers.length,
      );
      if (responsePointer == nullptr) {
        throw const GemmaChatbotException('RAG context 응답 생성에 실패했습니다.');
      }
      return _fromNativeUtf8(responsePointer);
    } finally {
      _free(promptPointer.cast<Void>());
      for (final contextPointer in contextPointers) {
        _free(contextPointer.cast<Void>());
      }
      if (contextsPointer != nullptr) {
        _free(contextsPointer.cast<Void>());
      }
      if (responsePointer != nullptr) {
        _freeString(responsePointer);
      }
    }
  }

  void dispose() {
    final handle = _handle;
    if (handle != nullptr) {
      _destroy(handle);
      _handle = nullptr;
    }
  }

  GemmaModelMetrics metrics() {
    return GemmaModelMetrics(
      tokens: _lastTokens(_handle),
      generationTimeMs: _lastGenerationTime(_handle),
      firstTokenTimeMs: _lastFirstTokenTime(_handle),
    );
  }

  Pointer<Int8> _toNativeUtf8(String value) {
    final units = utf8.encode(value);
    final pointer = _malloc(units.length + 1).cast<Uint8>();
    if (pointer == nullptr) {
      throw const GemmaChatbotException('native 문자열 메모리 할당에 실패했습니다.');
    }

    for (var i = 0; i < units.length; i += 1) {
      pointer[i] = units[i];
    }
    pointer[units.length] = 0;
    return pointer.cast<Int8>();
  }

  String _fromNativeUtf8(Pointer<Int8> pointer) {
    final bytes = <int>[];
    final bytePointer = pointer.cast<Uint8>();
    var index = 0;
    while (bytePointer[index] != 0) {
      bytes.add(bytePointer[index]);
      index += 1;
    }
    return utf8.decode(bytes);
  }
}
