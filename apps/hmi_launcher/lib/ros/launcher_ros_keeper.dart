import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

import '../domain/launcher_config.dart';

typedef RosFactory = Ros Function(String url);

/// L009: Unified ROS connection keeper for the launcher.
///
/// Simplified from ota_monitor's RosKeeper. Registers a single Ros instance
/// via GetX that all embedded plugin collectors share.
///
/// Creates and maintains a single `Ros` instance registered via GetX,
/// which embedded plugin collectors (OtaCollector, AdswCollector, etc.)
/// can access via `Get.find<Ros>()`.
/// 원격 호스트의 domain_agent 가 구독하는 토픽 (MMF ext_comm/domain_agent).
const String kDomainSetTopic = '/mmf/domain/set';

/// 원격 호스트의 domain_agent 가 결과를 latch 발행하는 토픽.
const String kDomainStateTopic = '/mmf/domain/state';

/// 원격 전파 결과.
///
/// `sent` 와 `acked` 를 구분하는 이유: rosbridge 가 publish 를 받아 주는 것과 원격
/// 호스트의 agent 가 실제로 파일에 쓴 것은 다르다. 발행 직후 discovery 가 끝나기
/// 전이면 샘플이 유실될 수 있는데(실측: `ros2 topic pub --once` 가 그렇다), 그때
/// "전송 성공" 이라고 알리면 **조용한 거짓 성공**이 된다.
enum DomainPublishResult {
  /// agent 가 그 값으로 파일에 썼음을 상태 토픽으로 확인했다.
  acked,

  /// 발행은 했지만 확인 못 함 — agent 가 없거나(구버전 ext-ros2) 응답이 늦다.
  unconfirmed,

  /// 발행 자체가 실패 (ROS 미연결 등).
  failed,
}

class LauncherRosKeeper {
  LauncherRosKeeper(
    this.cfg, {
    RosFactory? rosFactory,
  }) : _rosFactory = rosFactory ?? ((url) => Ros(url: url));

  final LauncherConfig cfg;
  final RosFactory _rosFactory;

  Ros? _ros;
  Topic? _statusTopic;
  Topic? _domainSetTopic;
  Topic? _domainStateTopic;
  String? _lastDomainState;
  final Map<String, Topic> _appStatusTopics = {};
  Set<String> _runningAppIds = {};
  Timer? _reconnectPoll;
  Timer? _heartbeatTimer;
  StreamSubscription<Status>? _statusSub;

  bool _stopping = false;
  bool _reconnecting = false;
  // Held true from a reconnect kick until the connection actually settles
  // (_onConnected) or a safety timeout fires — prevents the 2s watchdog from
  // firing overlapping connect() calls that close+reopen the socket (churn).
  Timer? _reconnectGuardTimer;

  Ros get ros => _ros ?? (throw StateError('ROS not initialized'));

  /// Number of consecutive reconnect failures.
  final ValueNotifier<int> consecutiveFailures = ValueNotifier<int>(0);

  Future<void> start() async {
    await stop();
    _stopping = false;

    _ros = _rosFactory(cfg.rosUrl.toString());

    _statusTopic = Topic(
      ros: _ros!,
      name: cfg.statusTopic,
      type: 'std_msgs/String',
      reconnectOnClose: true,
    );
    // 도메인 토픽은 **미리** advertise 한다. Apply 시점에 새로 만들면 discovery 가
    // 끝나기 전에 발행돼 첫 샘플이 유실될 수 있다(실측). 연결 직후 만들어 두면
    // 사용자가 Settings 를 열 때쯤엔 이미 매칭돼 있다.
    _domainSetTopic = Topic(
      ros: _ros!,
      name: kDomainSetTopic,
      type: 'std_msgs/String',
      reconnectOnClose: true,
    );
    _domainStateTopic = Topic(
      ros: _ros!,
      name: kDomainStateTopic,
      type: 'std_msgs/String',
      reconnectOnClose: true,
    );
    _syncAppStatusTopics();

    _statusSub = _ros!.statusStream.listen(
      (s) async {
        debugPrint('[LauncherROS] status=$s');
        if (s == Status.connected) {
          await _onConnected();
        }
      },
      onError: (e, st) => debugPrint('[LauncherROS] statusStream error: $e'),
      onDone: () => debugPrint('[LauncherROS] statusStream done'),
    );

    // Watchdog poll
    _reconnectPoll?.cancel();
    _reconnectPoll = Timer.periodic(
        Duration(seconds: cfg.rosReconnectIntervalSec), (_) async {
      final r = _ros;
      if (_stopping || r == null) return;
      if (_reconnecting) return;
      if (await _isStableConnected(r)) return;
      _kickReconnect();
    });

    // Heartbeat timer
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(Duration(seconds: cfg.heartbeatIntervalSec), (_) async {
      _publishHeartbeats();
    });

    _kickReconnect();
  }

  Future<void> stop() async {
    _stopping = true;
    _reconnectPoll?.cancel();
    _reconnectPoll = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectGuardTimer?.cancel();
    _reconnectGuardTimer = null;
    _reconnecting = false;
    await _statusSub?.cancel();
    _statusSub = null;
    _ros?.close();
    _ros = null;
    _statusTopic = null;
    _domainSetTopic = null;
    _domainStateTopic = null;
    _lastDomainState = null;
    _appStatusTopics.clear();
  }

  /// Updates app heartbeat topics for embedded apps currently kept alive by
  /// the launcher. Each app publishes std_msgs/String(data: running) on
  /// `/app_status/{appId}` while it remains open.
  /// 원격 호스트(차량 컴퓨트)의 도메인 파일을 갱신해 달라고 요청한다.
  ///
  /// 런처는 **자기 호스트의** domain.env 만 쓴다. Autoware·MMF core·ext-ros2 가 다른
  /// 호스트에 있으면 그쪽은 옛 값으로 남으므로(실측 2026-09-04: 81 을 5/5 로 저장했으나
  /// 151 은 42/42), 그 호스트의 `domain_agent` 에게 rosbridge 로 요청을 보낸다.
  ///
  /// 페이로드는 domain.env 와 같은 `KEY=VALUE` 형식이다 — 사람이 로그만 봐도 무엇이
  /// 오갔는지 안다. agent 는 값만 취해 정규 형식으로 다시 쓴다(원격이 보낸 임의
  /// 텍스트가 그 호스트의 설정 파일이 되지 않도록).
  ///
  /// ⚠ 이 요청은 **도메인을 바꾸기 전** 도메인으로 전달된다(바꾼 뒤엔 서로 안 보인다).
  /// 그래서 rosbridge 가 아직 옛 ROS 도메인에 있는 이 시점에 보내는 것이 맞다.
  /// 반영에는 그 호스트의 컨테이너 재생성이 필요하다 — agent 는 파일만 쓴다.
  ///
  /// 연결이 없으면 false. 호출부는 이 값으로 "원격 반영 요청됨/못 보냄" 을 알린다.
  Future<DomainPublishResult> publishDomainRequest(
      {required int dds, required int ros}) async {
    final set = _domainSetTopic;
    final state = _domainStateTopic;
    if (set == null) return DomainPublishResult.failed;

    // agent 의 응답을 받기 위해 먼저 구독한다. 상태 토픽은 latch(TRANSIENT_LOCAL)
    // 라 구독 직후 현재 값이 한 번 온다 — 그건 아직 옛 값일 수 있으므로 우리가
    // 보낸 값과 일치하는지로 판정한다.
    _lastDomainState = null;
    try {
      await state?.subscribe((msg) async {
        final d = msg['data'];
        if (d is String) _lastDomainState = d;
      });
    } catch (e) {
      debugPrint('[LauncherROS] domain state subscribe failed: $e');
    }

    try {
      await set.advertise();
      await set.publish({
        'data': 'DDS_DOMAIN_ID=$dds\nROS_DOMAIN_ID=$ros\n',
      });
      debugPrint('[LauncherROS] domain request published dds=$dds ros=$ros');
    } catch (e) {
      debugPrint('[LauncherROS] domain request failed: $e');
      return DomainPublishResult.failed;
    }

    // agent 가 파일에 쓴 값을 상태로 되돌려 준다 — 그 값이 우리가 보낸 것과 같으면
    // 반영 확인이다. 최대 3 초(0.25s × 12) 기다린다.
    final want = 'file_dds=$dds;file_ros=$ros';
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final st = _lastDomainState;
      if (st != null && st.contains(want)) {
        debugPrint('[LauncherROS] domain request acked: $st');
        return DomainPublishResult.acked;
      }
    }
    debugPrint('[LauncherROS] domain request unconfirmed (state=$_lastDomainState)');
    return DomainPublishResult.unconfirmed;
  }

  void setRunningAppIds(Iterable<String> appIds) {
    final normalized = {
      for (final id in appIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    if (setEquals(_runningAppIds, normalized)) return;
    _runningAppIds = normalized;
    debugPrint('[LauncherROS] running apps=${_runningAppIds.join(', ')}');
    _syncAppStatusTopics();
    _publishHeartbeats();
  }

  void _syncAppStatusTopics() {
    final r = _ros;
    if (r == null) return;

    _appStatusTopics.removeWhere((appId, _) => !_runningAppIds.contains(appId));
    for (final appId in _runningAppIds) {
      _appStatusTopics.putIfAbsent(
        appId,
        () {
          final topic = Topic(
            ros: r,
            name: '/app_status/$appId',
            type: 'std_msgs/String',
            reconnectOnClose: true,
          );
          debugPrint('[LauncherROS] app status topic=/app_status/$appId');
          if (r.status == Status.connected) {
            unawaited(topic.advertise());
          }
          return topic;
        },
      );
    }
  }

  void _publishHeartbeats() {
    final r = _ros;
    if (r == null || r.status != Status.connected) return;
    try {
      _statusTopic?.publish({'data': 'running'});
      for (final entry in _appStatusTopics.entries) {
        entry.value.publish({'data': 'running'});
      }
    } catch (e) {
      debugPrint('[LauncherROS] heartbeat publish error: $e');
    }
  }

  Future<bool> _isStableConnected(Ros r) async {
    return r.status == Status.connected;
  }

  void _kickReconnect() {
    if (_reconnecting) return;

    final r = _ros;
    if (r == null) return;

    if (r.status == Status.connected) {
      consecutiveFailures.value = 0;
      return;
    }

    // Hold the guard across the async connect: cleared by _onConnected on
    // success, or by the safety timer if the attempt never settles. Previously
    // the guard was released synchronously, so the next 2s watchdog tick fired
    // another connect() mid-handshake — closing + reopening the socket in a
    // ~2s churn loop that reset every shared-Ros subscription.
    _reconnecting = true;
    consecutiveFailures.value++;
    debugPrint('[LauncherROS] reconnect attempt ${consecutiveFailures.value}');

    r.connect();

    _reconnectGuardTimer?.cancel();
    _reconnectGuardTimer = Timer(const Duration(seconds: 8), () {
      _reconnecting = false;
    });
  }

  Future<void> _onConnected() async {
    consecutiveFailures.value = 0;
    // Connection settled — release the reconnect guard + cancel the safety timer.
    _reconnecting = false;
    _reconnectGuardTimer?.cancel();
    _reconnectGuardTimer = null;

    // Register the global Ros ONCE. Replace only when the instance actually
    // changed (e.g. a rosUrl change recreated it). Replacing with the SAME
    // instance on every reconnect churns GetX and orphaned the shared-Ros
    // subscriptions of lfc_monitor / adsw_monitor (diagnostics tab).
    if (!Get.isRegistered<Ros>()) {
      Get.put<Ros>(_ros!);
      debugPrint('[LauncherROS] Ros registered in GetX');
    } else if (!identical(Get.find<Ros>(), _ros)) {
      Get.replace<Ros>(_ros!);
      debugPrint('[LauncherROS] Ros replaced in GetX (instance changed)');
    }

    try {
      await _statusTopic?.advertise();
      for (final topic in _appStatusTopics.values) {
        await topic.advertise();
      }
    } catch (e) {
      debugPrint('[LauncherROS] status advertise error: $e');
    }
  }
}
