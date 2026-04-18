// Mock OTA Manager — rosbridge WebSocket server
//
// A mock server that plays the OTA Manager role.
// It speaks the real rosbridge protocol (JSON over WebSocket) and responds to
// GetAppUpdateSettings / GetAppUpdateState / SetAppUpdate requests.
//
// Usage example:
//   final mock = MockOtaManager();
//   await mock.start();                          // OS picks a free port
//   final cfg = AppConfig(rosUrl: Uri.parse('ws://localhost:${mock.port}'), ...);
//   ...
//   await mock.stop();

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ota_monitor/data/ota_data.dart';

// ── App record ───────────────────────────────────────────────────────────

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
  /// Initial app list used by tests.
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

  /// Actual port the server bound to (valid after start()).
  int get port => _server!.port;

  // ── Received-request log (for test assertions) ───────────────────────
  final List<Map<String, dynamic>> receivedRequests = [];

  // ── Server start / stop ──────────────────────────────────────────────

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

  // ── rosbridge protocol handling ──────────────────────────────────────

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
        // advertise needs no special handling — ignore
        break;
      case 'publish':
        final topic = msg['topic'] as String? ?? '';
        final payload = (msg['msg'] as Map<String, dynamic>?) ?? {};
        receivedRequests.add({'topic': topic, 'msg': payload});
        _onPublish(topic, payload);
        break;
      default:
        // unknown op — ignore
        break;
    }
  }

  /// Called when a client subscribes to a topic.
  /// When NotifyAppUpdateStatus is subscribed, seed the initial app list.
  void _onSubscribe(String topic) {
    if (topic == otaResponseTopics[4]) {
      // NotifyAppUpdateStatus — seed initial statuses after a short delay
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

  /// Called when a client publishes to a request topic.
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
      // SetAppUpdate (update request)
      _handleSetUpdate(msg);
    }
    // Ignore other topics (e.g. status heartbeat).
  }

  void _handleGetSettings(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    final id = msg['id'];
    final app = _findApp(appName);
    _broadcast(otaResponseTopics[0], {
      if (id != null) 'id': id,
      'app_name': appName,
      'app_settings': app?.settings ?? '{}',
      'ret_code': 1,
    });
  }

  void _handleSetSettings(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    final id = msg['id'];
    _broadcast(otaResponseTopics[1], {
      if (id != null) 'id': id,
      'app_name': appName,
      'ret_code': 1,
    });
  }

  void _handleGetState(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    final id = msg['id'];
    final app = _findApp(appName);
    _broadcast(otaResponseTopics[2], {
      if (id != null) 'id': id,
      'app_name': appName,
      'app_state_info': app?.state ?? 'unknown',
      'ret_code': 1,
    });
  }

  void _handleSetUpdate(Map<String, dynamic> msg) {
    final appName = msg['app_name'] as String? ?? '';
    final id = msg['id'];

    // 1) Immediate: acceptance response for the update request.
    _broadcast(otaResponseTopics[3], {
      if (id != null) 'id': id,
      'app_name': appName,
      'ret_code': 1,
    });

    // 2) Shortly after: notify update progress.
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      _broadcast(otaResponseTopics[4], {
        'app_name': appName,
        'status': 'updating',
      });
    });

    // 3) Notify completion.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _broadcast(otaResponseTopics[4], {
        'app_name': appName,
        'status': 'complete',
      });
    });
  }

  // ── Convenience methods ──────────────────────────────────────────────

  /// Send a NotifyAppUpdateStatus message directly (used for manual control in tests).
  void sendNotifyStatus(String appName, String status) {
    _broadcast(otaResponseTopics[4], {
      'app_name': appName,
      'status': status,
    });
  }

  // ── Internal helpers ─────────────────────────────────────────────────

  AppRecord? _findApp(String name) {
    try {
      return initialApps.firstWhere((a) => a.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Broadcast a rosbridge publish message to all connected clients.
  void _broadcast(String topic, Map<String, dynamic> msgPayload) {
    final frame = jsonEncode({'op': 'publish', 'topic': topic, 'msg': msgPayload});
    for (final ws in List.of(_clients)) {
      try {
        ws.add(frame);
      } catch (_) {}
    }
  }
}
