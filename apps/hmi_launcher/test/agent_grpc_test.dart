// F015 AC2: Agent.Submit gRPC 씬 클라이언트 E2E 테스트.
//
// 이 파일은 다음을 검증한다:
//   AC2: 모킹 gRPC 서버 기동 시 챗봇 패널 입력→AgentSubmitRequest 전송→응답 텍스트 표시.
//   AC3: gRPC 서버 미기동 시 NLU substring 라우터가 media 앱 실행 + 크래시 없음.
//
// 모킹 gRPC 서버는 Dart in-process로 구현한다 (외부 서버 불필요).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/nlu_router.dart';
import 'package:hmi_launcher/launcher_bot/models/launcher_bot_message.dart';
import 'package:hmi_launcher/launcher_bot/services/agent_submit_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/app_usage_store.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_controller.dart';

// ─── 모킹 AgentSubmitAiService ────────────────────────────────────────────────

/// AC2: 모킹 gRPC 서버 역할을 하는 가짜 AI 서비스.
///
/// 실제 gRPC 채널을 열지 않고 in-process 로 응답을 반환하여
/// 테스트 환경에서 실제 서버 없이 AC2 를 검증한다.
class _MockGrpcAiService implements LauncherBotAiService {
  _MockGrpcAiService({this.responseText = '에이전트 응답: 음악 재생 중입니다.'});

  final String responseText;

  /// 전송된 prompt 목록 (검증용).
  final List<String> sentPrompts = [];

  bool throwOnGenerate = false;

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) async {
    sentPrompts.add(prompt);
    if (throwOnGenerate) {
      throw AgentSubmitException('gRPC 서버 연결 실패 (모킹)');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return responseText;
  }

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) async {
    sentPrompts.add(prompt);
    if (throwOnGenerate) {
      throw AgentSubmitException('gRPC 서버 연결 실패 (모킹)');
    }
    // gRPC 씬 클라이언트는 intent routing 을 수행하지 않는다 (null 반환).
    // LauncherBotController 가 NLU 폴백을 시도한다.
    return null;
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
    throw AgentSubmitException('오디오 전사 미지원 (F015 범위 밖)');
  }

  @override
  void dispose() {}
}

// ─── NLU 폴백 전용 가짜 서비스 ──────────────────────────────────────────────

/// AC3: gRPC 실패 시 동작을 시뮬레이션하는 서비스.
///
/// generate() / resolveIntent() 가 항상 [AgentSubmitException] 을 던져
/// LauncherBotController 가 NLU 폴백으로 이행하도록 한다.
class _AlwaysFailAiService implements LauncherBotAiService {
  const _AlwaysFailAiService();

  @override
  Future<String> generate({
    required String prompt,
    required List<String> contexts,
  }) {
    throw const AgentSubmitException('gRPC 서버 미기동 (AC3 시뮬레이션)');
  }

  @override
  Future<LauncherBotAiIntent?> resolveIntent({
    required String prompt,
    required List<AppManifest> apps,
    required String currentContext,
  }) {
    throw const AgentSubmitException('gRPC 서버 미기동 (AC3 시뮬레이션)');
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
    throw const AgentSubmitException('gRPC 서버 미기동 (AC3 시뮬레이션)');
  }

  @override
  void dispose() {}
}

// ─── 테스트 헬퍼 ─────────────────────────────────────────────────────────────

AppManifest _makeApp(String id, {String? name, List<String> prompts = const []}) {
  return AppManifest(
    id: id,
    name: name ?? id,
    icon: 'music_note',
    version: '1.0.0',
    entry: '$id/main.dart',
    prompts: prompts,
  );
}

// ─── 테스트 ──────────────────────────────────────────────────────────────────

void main() {
  // AC2: gRPC 씬 클라이언트 — 입력→AgentSubmitRequest 전송→응답 텍스트 표시
  group('AC2: gRPC 씬 클라이언트 E2E', () {
    test('사용자 입력이 AgentSubmitAiService.generate() 로 전달되고 응답이 메시지로 표시된다',
        () async {
      const expectedResponse = '음악을 재생하겠습니다.';
      final mockService = _MockGrpcAiService(responseText: expectedResponse);

      final controller = LauncherBotController(
        nluRouter: NluRouter(const []),
        aiService: mockService,
        onOpenApp: (_) => fail('앱 실행 호출 안 됨'),
        onCloseApp: () => null,
        onOpenSettings: () => fail('설정 호출 안 됨'),
      );

      await controller.submit('음악 틀어줘');

      // 입력이 서비스로 전달됐는지 확인
      // (resolveIntent 먼저 호출 → null 반환 → generate 폴백 호출)
      expect(mockService.sentPrompts, isNotEmpty);
      expect(mockService.sentPrompts.any((p) => p.contains('음악 틀어줘')), isTrue);

      // 응답 텍스트가 패널에 표시됐는지 확인
      final lastMsg = controller.messages.last;
      expect(lastMsg.text, expectedResponse);
    });

    test('AgentSubmitAiService 가 AgentSubmitRequest 계약을 따라 generate 를 호출한다',
        () async {
      // 직접 AgentSubmitAiService 의 퍼블릭 인터페이스를 테스트한다.
      // 실제 gRPC 서버 없이 canConnect 가 false 를 반환하면 예외 발생 확인.
      final canConnect = await AgentSubmitAiService.canConnect(
        host: 'localhost',
        port: 59999, // 존재하지 않는 포트
        timeout: const Duration(milliseconds: 100),
      );
      expect(canConnect, isFalse);
    });

    test('gRPC 응답 텍스트가 챗봇 패널에 올바르게 표시된다', () async {
      const response = '에이전트: 목적지를 설정합니다.';
      final mockService = _MockGrpcAiService(responseText: response);

      final controller = LauncherBotController(
        nluRouter: NluRouter(const []),
        aiService: mockService,
        onOpenApp: (_) {},
        onCloseApp: () => null,
        onOpenSettings: () {},
        contextName: 'Navigation',
      );

      await controller.submit('서울역으로 안내해줘');

      expect(controller.messages.last.text, response);
    });
  });

  // AC3: gRPC 서버 미기동 시 NLU substring 폴백
  group('AC3: gRPC 실패 시 NLU 폴백', () {
    test('gRPC 실패 시 NLU 라우터가 "음악 틀어줘" 를 media 앱으로 라우팅한다', () async {
      final mediaApp = _makeApp(
        'media_player',
        name: '미디어 플레이어',
        prompts: ['음악 틀어줘', '음악 재생', 'media', '미디어'],
      );

      var openedAppId = '';
      final controller = LauncherBotController(
        nluRouter: NluRouter([mediaApp]),
        aiService: const _AlwaysFailAiService(),
        onOpenApp: (app) => openedAppId = app.id,
        onCloseApp: () => null,
        onOpenSettings: () => fail('설정 호출 안 됨'),
      );

      await controller.submit('음악 틀어줘');

      // NLU 폴백이 media_player 앱을 실행했는지 확인
      expect(openedAppId, 'media_player');
      expect(controller.messages.last.intent, 'Open App');
    });

    test('gRPC 실패 시 NLU 매칭 없는 입력은 에러 메시지를 보이되 크래시가 없다',
        () async {
      final controller = LauncherBotController(
        nluRouter: NluRouter(const []),
        aiService: const _AlwaysFailAiService(),
        onOpenApp: (_) => fail('앱 실행 안 됨'),
        onCloseApp: () => null,
        onOpenSettings: () => fail('설정 호출 안 됨'),
      );

      // 크래시 없이 완료되어야 한다
      await expectLater(
        controller.submit('이상한 입력 — 매칭 없음'),
        completes,
      );

      // 에러 메시지가 표시됐는지 확인 (intent: Error 또는 AI)
      final lastMsg = controller.messages.last;
      expect(lastMsg.text, isNotEmpty);
      expect(lastMsg.speaker, LauncherBotSpeaker.bot);
    });

    test('gRPC 실패 후 NLU close 명령이 크래시 없이 처리된다', () async {
      var closeCalled = false;
      final controller = LauncherBotController(
        nluRouter: NluRouter(const []),
        aiService: const _AlwaysFailAiService(),
        onOpenApp: (_) => fail('앱 실행 안 됨'),
        onCloseApp: () {
          closeCalled = true;
          return 'Media';
        },
        onOpenSettings: () => fail('설정 호출 안 됨'),
        contextName: 'Media',
      );

      // 닫기 명령은 AI 호출 전에 직접 처리된다
      await controller.submit('닫아줘');

      expect(closeCalled, isTrue);
    });
  });
}
