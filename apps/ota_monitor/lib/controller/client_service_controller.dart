import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/logging/app_log.dart';

/// F021 — Client-service controller for the OTA Monitor.
///
/// Drives the four DDS topics that make up the Manager's "client"
/// surface (see oss_multisw_framework/idl/dds/ota_mgr/OtamClientServiceMsg.idl):
///
///   - request:    /mmf/otamanager/otaclient_service/SetOtaClientRegistration
///   - response:   /mmf/otamanager/otaclient_service/SetOtaClientRegistrationResponse
///   - notify:     /mmf/otamanager/otaclient_service/NotifyOtaManagerReady
///   - notify:     /mmf/otamanager/otaclient_service/NotifyAppUpdateStatus
///
/// State is exposed as ChangeNotifier-style listenables so the Client tab
/// (F021) can rebuild without GetX. The OtaCollector (F009 / F011) keeps
/// owning its own subscription to NotifyAppUpdateStatus for the Apps tab —
/// roslibdart broadcasts WebSocket messages to every listener so the two
/// consumers don't interfere.
class ClientServiceController extends ChangeNotifier {
  ClientServiceController({
    required Ros ros,
    Topic Function(Ros, String, String)? topicFactory,
    int historyLimit = 50,
  })  : _ros = ros,
        _topicFactory = topicFactory ??
            ((r, name, type) => Topic(ros: r, name: name, type: type)),
        _historyLimit = historyLimit;

  final Ros _ros;
  final Topic Function(Ros, String, String) _topicFactory;
  final int _historyLimit;

  // ── topic constants ─────────────────────────────────────────────────
  static const String topicRegistration =
      '/mmf/otamanager/otaclient_service/SetOtaClientRegistration';
  static const String topicRegistrationResponse =
      '/mmf/otamanager/otaclient_service/SetOtaClientRegistrationResponse';
  static const String topicManagerReady =
      '/mmf/otamanager/otaclient_service/NotifyOtaManagerReady';
  static const String topicAppUpdateStatus =
      '/mmf/otamanager/otaclient_service/NotifyAppUpdateStatus';

  static const String _typeReg =
      'otamanager/SetOtaClientRegistration';
  static const String _typeRegRes =
      'otamanager/SetOtaClientRegistrationResponse';
  static const String _typeReady =
      'otamanager/NotifyOtaManagerReady';
  static const String _typeStatus =
      'otamanager/NotifyAppUpdateStatus';

  // ── observable state (read by the Client tab) ───────────────────────
  /// Most recent client_id returned by the Manager, or null if we have
  /// not yet been issued one. The Client tab uses this for the highlight
  /// match in the NotifyAppUpdateStatus list.
  int? get clientId => _clientId;
  int? _clientId;

  /// True after the first NotifyOtaManagerReady arrives. Cleared if the
  /// caller re-runs setup() (e.g. after a SettingsController URL flip).
  bool get managerReady => _managerReady;
  bool _managerReady = false;

  /// Most recent NotifyAppUpdateStatus messages, newest first, capped at
  /// [_historyLimit].
  List<Map<String, dynamic>> get statuses => List.unmodifiable(_statuses);
  final List<Map<String, dynamic>> _statuses = [];

  // ── plumbing ────────────────────────────────────────────────────────
  Topic? _regPub;
  Topic? _regResSub;
  Topic? _readySub;
  Topic? _statusSub;
  bool _setup = false;

  /// Wire up the four topics. Idempotent — calling setup() twice is a
  /// no-op. Safe to call before Ros.connect() succeeds because
  /// roslibdart queues advertise/subscribe internally.
  Future<void> setup() async {
    if (_setup) return;
    try {
      _regPub = _topicFactory(_ros, topicRegistration, _typeReg);
      _regResSub =
          _topicFactory(_ros, topicRegistrationResponse, _typeRegRes);
      _readySub = _topicFactory(_ros, topicManagerReady, _typeReady);
      _statusSub =
          _topicFactory(_ros, topicAppUpdateStatus, _typeStatus);

      await _regResSub!.subscribe(_onRegistrationResponse);
      await _readySub!.subscribe(_onManagerReady);
      await _statusSub!.subscribe(_onStatus);
      await _regPub!.advertise();
      _setup = true;
      appLog('[client] setup complete');
    } catch (e) {
      appLog('[client] setup failed: $e', level: 'warn');
    }
  }

  /// Publish a SetOtaClientRegistration. Returns once the message has
  /// been handed to roslibdart (the Manager's response arrives later via
  /// the subscription on topicRegistrationResponse).
  Future<void> register(String clientName, List<String> appList) async {
    if (_regPub == null) {
      appLog('[client] register skipped: setup() not called yet',
          level: 'warn');
      return;
    }
    try {
      await _regPub!.publish({
        'client_name': clientName,
        'app_list': appList,
      });
      appLog('[client] register published name=$clientName apps=$appList');
    } catch (e) {
      appLog('[client] register publish error: $e', level: 'warn');
    }
  }

  // ── internal callbacks ──────────────────────────────────────────────
  Future<void> _onRegistrationResponse(Map<String, dynamic> msg) async {
    final id = (msg['client_id'] as num?)?.toInt();
    if (id == null) return;
    _clientId = id;
    appLog('[client] registration response client_id=$id');
    notifyListeners();
  }

  Future<void> _onManagerReady(Map<String, dynamic> msg) async {
    if (!_managerReady) {
      _managerReady = true;
      appLog('[client] manager ready');
      notifyListeners();
    }
  }

  Future<void> _onStatus(Map<String, dynamic> msg) async {
    _statuses.insert(0, Map<String, dynamic>.from(msg));
    if (_statuses.length > _historyLimit) {
      _statuses.removeRange(_historyLimit, _statuses.length);
    }
    notifyListeners();
  }

  /// Test/debug helper: push a status directly into the local buffer
  /// without waiting for a real DDS message.
  @visibleForTesting
  void injectStatusForTest(Map<String, dynamic> msg) =>
      _onStatus(msg);

  /// Test/debug helper: simulate a registration response.
  @visibleForTesting
  void injectRegistrationResponseForTest(int id) =>
      _onRegistrationResponse({'client_id': id});

  /// Test/debug helper: simulate manager ready.
  @visibleForTesting
  void injectManagerReadyForTest() =>
      _onManagerReady(<String, dynamic>{});

  @override
  void dispose() {
    // We don't unsubscribe roslibdart topics here — the singleton Ros is
    // shared and may outlive this controller. Other listeners (Apps tab,
    // smoke test) keep working unaffected.
    super.dispose();
  }
}
