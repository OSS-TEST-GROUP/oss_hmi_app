// F015: 내장 LLM FFI 완전 제거.
//
// 이 파일은 이전에 chatbot_bridge.cpp / llama_cpp 를 dart:ffi 를 통해 직접 호출했다.
// F015 에서 AI 백엔드를 Agent.Submit gRPC(agent_submit_ai_service.dart) 로 교체함에 따라
// FFI 의존이 전량 제거됐다.
//
// GemmaChatbotException 은 FallbackLauncherBotAiService 와의 호환성을 위해 유지한다.
// GemmaChatbotService / GemmaLauncherBotAiService 는 F015 SHOULD-2 에서 죽은코드 제거됐다.

/// F015 AC1: 내장 LLM 런타임 연결 불가 예외.
///
/// FallbackLauncherBotAiService 가 오디오 전사 미지원을 알릴 때 사용한다.
class GemmaChatbotException implements Exception {
  const GemmaChatbotException(this.message);

  final String message;

  @override
  String toString() => message;
}
