// QA(docs/qa): 범용 rosbridge WebSocket mock (테스트용).
//
// 실 rosbridge 없이 roslibdart 의 Ros 가 붙을 수 있는 최소 서버.
// - HttpServer.bind(localhost, 0) 로 빈 포트 자동 선택 → `ws://localhost:${mock.port}`
// - rosbridge v2 JSON op(subscribe/advertise/publish/unsubscribe/call_service) 수용
// - publish(topic, msg) 로 구독자에게 프레임 푸시 (컬렉터/패널 검증용)
//
// 사용:
//   final mock = MockRosbridge();
//   await mock.start();
//   ... Ros(url: 'ws://localhost:${mock.port}') ...
//   await mock.stop();
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockRosbridge {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Map<String, Set<WebSocket>> _subs = {};

  /// call_service 응답 값 (service 이름 → values map). 없으면 빈 응답.
  final Map<String, Map<String, dynamic>> serviceResponses = {};

  int get port => _server!.port;
  int get clientCount => _clients.length;
  Set<String> get subscribedTopics => _subs.keys.toSet();

  Future<void> start() async {
    _server = await HttpServer.bind('localhost', 0);
    _server!.listen((HttpRequest req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      _clients.add(ws);
      ws.listen(
        (data) => _onMessage(ws, data as String),
        onDone: () => _remove(ws),
        onError: (_) => _remove(ws),
        cancelOnError: true,
      );
    });
  }

  Future<void> stop() async {
    for (final ws in List<WebSocket>.from(_clients)) {
      await ws.close().catchError((_) {});
    }
    _clients.clear();
    _subs.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void _remove(WebSocket ws) {
    _clients.remove(ws);
    for (final s in _subs.values) {
      s.remove(ws);
    }
  }

  void _onMessage(WebSocket ws, String data) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['op']) {
      case 'subscribe':
        final t = msg['topic'] as String?;
        if (t != null) _subs.putIfAbsent(t, () => <WebSocket>{}).add(ws);
        break;
      case 'unsubscribe':
        final t = msg['topic'] as String?;
        if (t != null) _subs[t]?.remove(ws);
        break;
      case 'call_service':
        final service = msg['service'] as String?;
        final id = msg['id'];
        ws.add(jsonEncode({
          'op': 'service_response',
          'service': service,
          'values': serviceResponses[service] ?? <String, dynamic>{},
          'result': true,
          if (id != null) 'id': id,
        }));
        break;
      case 'advertise':
      case 'unadvertise':
      case 'publish':
        // 수용만 (heartbeat/상태 발행 등). 필요 시 확장.
        break;
    }
  }

  /// 주어진 토픽 구독자들에게 publish 프레임을 푸시.
  void publish(String topic, Map<String, dynamic> msgPayload) {
    final frame = jsonEncode({'op': 'publish', 'topic': topic, 'msg': msgPayload});
    for (final ws in _subs[topic] ?? const <WebSocket>{}) {
      ws.add(frame);
    }
  }
}
