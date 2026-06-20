import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';

import '../../domain/app_manifest.dart';
import '../../generated/agent.pbgrpc.dart';
import '../../generated/common.pb.dart';
import '../../generated/speech.pbgrpc.dart';
import 'app_usage_store.dart';
import 'launcher_bot_ai_service.dart';

/// F015: Agent.Submit gRPC 씬 클라이언트.
///
/// agent.proto 의 Agent.Submit RPC 를 호출해 텍스트 응답을 받는다.
/// 연결 실패(gRPC unavailable / deadline exceeded)는 모두 [AgentSubmitException] 으로
/// 변환되며, 호출 측(LauncherBotController)에서 NLU 폴백으로 이행한다.
///
/// ADR-014 결정 2: AgentSubmitAiService 가 Submit 을 호출.
/// Subscribe(ProactiveCard) 는 Phase 2 자리 확보 — 미구현 (UnimplementedError).
class AgentSubmitAiService implements LauncherBotAiService {
  AgentSubmitAiService({
    required String host,
    required int port,
    ClientChannel? channel,
  })  : _host = host,
        _port = port,
        _overrideChannel = channel;

  final String _host;
  final int _port;
  final ClientChannel? _overrideChannel;

  AgentClient? _client;
  SpeechServiceClient? _speechClient;
  ClientChannel? _channel;
  String _sessionId = '';

  /// Checks whether the gRPC server is reachable.
  ///
  /// Used by [isAvailable] to determine whether to build this service.
  static Future<bool> canConnect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lazily opens (and caches) the gRPC channel. Both [AgentClient] and
  /// [SpeechServiceClient] share this one channel — Agent.Submit and
  /// SpeechService are served by the same daemon on the same port, so the
  /// HTTP/2 connection is established once and reused across every call.
  ClientChannel _ensureChannel() {
    final existing = _channel;
    if (existing != null) return existing;
    final ch = _overrideChannel ??
        ClientChannel(
          _host,
          port: _port,
          options: const ChannelOptions(
            credentials: ChannelCredentials.insecure(),
          ),
        );
    _channel = ch;
    return ch;
  }

  AgentClient _ensureClient() {
    return _client ??= AgentClient(
      _ensureChannel(),
      options: CallOptions(timeout: const Duration(seconds: 10)),
    );
  }

  /// SpeechService stub on the shared, persistent channel. Created once and
  /// reused so spoken commands skip per-call channel/handshake setup — the
  /// latency the launcher bot was paying when each transcription opened a
  /// fresh connection.
  SpeechServiceClient _ensureSpeechClient() {
    return _speechClient ??= SpeechServiceClient(
      _ensureChannel(),
      // STT (whisper) can take several seconds, and the first call after a
      // daemon (re)start incurs CUDA warmup — keep the deadline generous.
      options: CallOptions(timeout: const Duration(seconds: 30)),
    );
  }

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async {
    final client = _ensureClient();
    final request = AgentSubmitRequest()
      ..text = prompt
      ..contexts.addAll(contexts)
      ..sessionId = _sessionId;

    try {
      final response = await client.submit(request);
      _sessionId = response.sessionId;
      return response.text;
    } on GrpcError catch (e) {
      throw AgentSubmitException(
        'gRPC Submit 실패 [${e.codeName}]: ${e.message ?? e.toString()}',
      );
    }
  }

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
    // Agent.Submit 은 자유형 텍스트 응답만 반환한다.
    // intent routing 은 LauncherBotController 에서 NLU 폴백으로 처리한다.
    return null;
  }

  @override
  Future<LauncherBotAiAppSuggestion?> suggestAppToOpen({
    required List<AppManifest> apps,
    required List<AppUsageStats> usages,
    required String currentContext,
  }) async {
    // Agent.Submit 은 앱 제안을 직접 제공하지 않는다.
    // ProactiveCard(Phase 2) 구현 전까지 null 반환.
    return null;
  }

  @override
  Future<String> transcribeAudio({
    required Float32List pcm,
    required int sampleRate,
    required int channels,
  }) async {
    if (pcm.isEmpty) {
      throw const AgentSubmitException('전사할 음성 데이터가 비어 있습니다.');
    }

    final client = _ensureSpeechClient();

    // Float32List PCM([-1,1]) → little-endian f32 bytes. All target platforms
    // (aarch64 board, x86 dev) are little-endian, so the raw view is pcm_f32le
    // as the daemon's decoder expects — no quantisation, no copy of samples.
    final audioBytes =
        pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes);

    final request = TranscribeRequest()
      ..audio = audioBytes
      ..format = (AudioFormat()
        ..sampleRateHz = sampleRate
        ..encoding = 'pcm_f32le')
      ..enablePostprocess = true;

    try {
      final response = await client.transcribe(request);
      if (!response.success) {
        throw AgentSubmitException(
          '음성 전사 실패: ${response.errorMessage.isEmpty ? "원인 미상" : response.errorMessage}',
        );
      }
      return response.transcript.trim();
    } on GrpcError catch (e) {
      throw AgentSubmitException(
        'gRPC Transcribe 실패 [${e.codeName}]: ${e.message ?? e.toString()}',
      );
    }
  }

  @override
  void dispose() {
    _client = null;
    _speechClient = null;
    _channel?.shutdown();
    _channel = null;
  }
}

/// [AgentSubmitAiService] 가 gRPC 호출 실패 시 던지는 예외.
///
/// [LauncherBotController] 는 이 예외를 잡아 NLU 폴백으로 이행한다.
class AgentSubmitException implements Exception {
  const AgentSubmitException(this.message);

  final String message;

  @override
  String toString() => 'AgentSubmitException: $message';
}
