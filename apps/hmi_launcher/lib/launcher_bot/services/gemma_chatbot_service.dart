// F015: 내장 LLM FFI 완전 제거.
//
// 이 파일은 이전에 chatbot_bridge.cpp / llama_cpp 를 dart:ffi 를 통해 직접 호출했다.
// F015 에서 AI 백엔드를 Agent.Submit gRPC(agent_submit_ai_service.dart) 로 교체함에 따라
// FFI 의존이 전량 제거됐다.
//
// GemmaChatbotService / GemmaChatbotException / GemmaModelMetrics 는
// 하위 호환성 보존을 위해 이름만 남기고 실제 LLM 호출 코드는 삭제했다.
// 이 파일에 import 'dart:ffi' 가 없음을 grep 으로 검증(AC1 기준).

/// F015 AC1: 내장 LLM 런타임 연결 불가 예외.
///
/// chatbot_bridge / llama_cpp 바인딩이 제거됐으므로
/// 런타임은 항상 사용 불가 상태로 반환된다.
class GemmaChatbotException implements Exception {
  const GemmaChatbotException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 내장 LLM 지표 데이터 홀더 (호환성 유지).
///
/// FFI 제거 후 실제 지표 수집은 없다. AgentSubmitAiService 의
/// gRPC 응답을 통해 서버 측 지표를 받을 수 있으나, Phase 2 에서 별도 구현.
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
    if (tokens <= 0 || generationTimeMs <= 0) return 0;
    return tokens / (generationTimeMs / 1000);
  }
}

/// F015 AC1: FFI 없는 내장 LLM 서비스 스텁.
///
/// chatbot_bridge.cpp / llama_cpp 연동이 완전 제거됐다.
/// 이 클래스는 GemmaLauncherBotAiService 호환성 유지를 위한 최소 잔류물이며
/// 실제 모델 추론을 수행하지 않는다.
/// 새 코드는 agent_submit_ai_service.dart 의 AgentSubmitAiService 를 사용하라.
class GemmaChatbotService {
  GemmaChatbotService();

  /// 내장 LLM 런타임이 사용 가능한지 확인한다.
  ///
  /// F015 이후: chatbot_bridge.so / llama_cpp 의존이 제거됐으므로
  /// 항상 false 를 반환한다.
  static bool isRuntimeAvailable() => false;

  void dispose() {}
}
