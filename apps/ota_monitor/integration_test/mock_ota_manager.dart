// Mock OTA Manager — rosbridge WebSocket server
//
// OTA Manager 역할을 하는 mock 서버.
// 실제 rosbridge 프로토콜(JSON over WebSocket)로 통신하며,
// GetAppUpdateSettings / GetAppUpdateState / SetAppUpdate 요청에 응답한다.
//
// 사용 예:
//   final mock = MockOtaManager();
//   await mock.start();                          // OS가 포트 자동 배정
//   final cfg = AppConfig(rosUrl: Uri.parse('ws://localhost:${mock.port}'), ...);
//   ...
//   await mock.stop();

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ota_monitor/data/ota_data.dart';

// ── 앱 레코드 ──────────────────────────────────────────────────────────────

class AppRecord {
  const AppRecord({
    required this.name,
    required this.status,
    required this.settings,
    required this.state,
  });

  final String name;
  final String status;
  final String settings; // JSON string
  final String state;
}

// ── MockOtaManager ──────────────────────────────────────────────────────────

class MockOtaManager {
  /// 테스트에서 사용할 초기 앱 목록.
  static const List<AppRecord> initialApps = [
    AppRecord(
      name: 'NavigationApp',
      status: 'Synced',
      settings: '{"auto_update":true,"interval":3600}',
      state: 'idle',
    ),
    AppRecord(
      name: 'MapUpdater',
      status: 'idle',
      settings: '{"schedule":"daily","max_size_mb":500}',
      state: 'ready',
    ),
    AppRecord(
      name: 'SensorFusion',
      status: 'Unknown',
      settings: '{}',
      state: 'standby',
    ),
  ];

  HttpServer? _server;
  final List<WebSocket> _clients = [];

  /// 서버가 바인딩된 실제 포트 (start() 호출 후 유효).
  int get port => _server!.port;

  // ── 수신된 요청 로그 (테스트 어서션용) ──────────────────────────────────
  final List<Map<String, dynamic>> receivedRequests = [];

  // ── 서버 시작/중지 ────────────────────────────────────────────────────────

  Future<void> start() async {
    _server = await HttpServer.bind('localhost', 0);
    _acceptConnections();
  }

  void _acceptConnections() {
    _server!.listen((HttpRequest request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) return;
      final ws = await WebSocketTransformer.upgrade(request);
      _clients.add(ws);
      _handleClient(ws);
    });
  }

  void _handleClient(WebSocket ws) {
    ws.listen(
      (data) => _handleMessage(ws, data as String),
      onDone: () => _clients.remove(ws),
      onError: (_) => _clients.remove(ws),
    );
  }

  Future<void> stop() async {
    for (final ws in List.of(_clients)) {
      await ws.close().catchError((_) {});
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  // ── rosbridge 프로토콜 처리 ───────────────────────────────────────────────

  void _handleMessage(WebSocket ws, String data) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final op = msg['op'] as String?;
    switch (op) {
      case 'subscribe':
        _onSubscribe(msg['topic'] as String? ?? '');
        break;
      case 'advertise':
        // advertise는 별도 처리 불필요 — 무시
        break;
      case 'publish':
        final topic = msg['topic'] as String? ?? '';
        final payload = (msg['msg'] as Map<String, dynamic>?) ?? {};
        receivedRequests.add({'topic': topic, 'msg': payload});
        _onPublish(topic, payload);
        break;
      default:
        // 알 수 없는 op — 무시
        break;
    }
  }

  /// 클라이언트가 특정 토픽을 subscribe할 때 호출.
  /// NotifyAppUpdateStatus 구독이 확인되면 초기 앱 목록을 전송한다.
  void _onSubscribe(String topic) {
    if (topic == otaResponseTopics[4]) {
      // NotifyAppUpdateStatus — 초기 앱 상태를 짧은 지연 후 전송
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        for (final app in initialApps) {
          _broadcast(otaResponseTopics[4], {
            'app_name': app.name,
            'status': app.status,
          });
        }
      });
    }
  }

  /// 클라이언트가 요청 토픽에 publish할 때 호출.
  void _onPublish(String topic, Map<String, dynamic> msg) {
    if (topic == otaRequestTopics[0]) {
      // GetAppUpdateSettings
      _handleGetSettings(msg);
    } else if (topic == otaRequestTopics[1]) {
      // SetAppUpdateSettings
      _handleSetSettings(msg);
    } else if (topic == otaRequestTopics[2]) {
      // GetAppUpdateState
      _handleGetState(msg);
    } else if (topic == otaRequestTopics[3]) {
      // SetAppUpdate (update 요청)
      _handleSetUpdate(msg);
    }
    // 그 외 토픽(status heartbeat 등)은 무시
  }

  void _handleGetSettings(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    final app = _findApp(appName);
    _broadcast(otaResponseTopics[0], {
      'app_name': appName,
      'app_settings': app?.settings ?? '{}',
      'ret_code': 1,
    });
  }

  void _handleSetSettings(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    _broadcast(otaResponseTopics[1], {
      'app_name': appName,
      'ret_code': 1,
    });
  }

  void _handleGetState(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    final app = _findApp(appName);
    _broadcast(otaResponseTopics[2], {
      'app_name': appName,
      'app_state_info': app?.state ?? 'unknown',
      'ret_code': 1,
    });
  }

  void _handleSetUpdate(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';

    // 1) 즉시: update 요청 수락 응답
    _broadcast(otaResponseTopics[3], {
      'app_name': appName,
      'ret_code': 1,
    });

    // 2) 잠시 후: 업데이트 진행 상태 통보
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      _broadcast(otaResponseTopics[4], {
        'app_name': appName,
        'status': 'updating',
      });
    });

    // 3) 업데이트 완료 통보
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _broadcast(otaResponseTopics[4], {
        'app_name': appName,
        'status': 'complete',
      });
    });
  }

  // ── 편의 메서드 ────────────────────────────────────────────────────────────

  /// 직접 NotifyAppUpdateStatus 메시지를 보낸다 (테스트에서 수동 제어 시 사용).
  void sendNotifyStatus(String appName, String status) {
    _broadcast(otaResponseTopics[4], {
      'app_name': appName,
      'status': status,
    });
  }

  // ── 내부 헬퍼 ──────────────────────────────────────────────────────────────

  AppRecord? _findApp(String name) {
    try {
      return initialApps.firstWhere((a) => a.name == name);
    } catch (_) {
      return null;
    }
  }

  /// rosbridge publish 메시지를 모든 연결된 클라이언트에 전송.
  void _broadcast(String topic, Map<String, dynamic> msgPayload) {
    final frame = jsonEncode({'op': 'publish', 'topic': topic, 'msg': msgPayload});
    for (final ws in List.of(_clients)) {
      try {
        ws.add(frame);
      } catch (_) {}
    }
  }
}
