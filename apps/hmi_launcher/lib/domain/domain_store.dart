import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 도메인 ID 유효 범위 (ROS 2 / Fast-DDS 공통 제약).
const int kMinDomainId = 0;
const int kMaxDomainId = 232;

/// 기본 도메인 **42** — 151 보드의 Autoware adsw 파티션(saved-service-list.yaml)이 42 다.
/// MMF 기본이 0 이던 동안 adsw_monitor 는 구독만 하고 발행자가 없어 화면이 전부 `null`
/// 이었다(실측 2026-08-04: domain 0 의 `/api/vehicle/status` Publisher count 0).
const int kDefaultDdsDomain = 42;

/// ROS2 평면 기본값. DDS 와 같은 42 로 출발한다 — 두 값이 같으면 오늘까지의 동작과
/// 완전히 동일하므로, 사용자가 실제로 갈라 놓기 전까지 회귀가 없다.
const int kDefaultRosDomain = 42;

/// MMF 서비스가 기동 시 읽는 도메인 파일 기본 경로.
/// `run-mmf.sh`(core+ext-ros2) / `run-ext-agl.sh` / docker compose(`--env-file`) 공통.
const String kDefaultDomainEnvFile = '/opt/mmf/config/domain.env';

/// 도메인 파일에 기록하는 키.
const String kDdsDomainEnvKey = 'DDS_DOMAIN_ID';
const String kRosDomainEnvKey = 'ROS_DOMAIN_ID';

/// 통신 **두 평면**의 도메인 ID 를 보관하고, MMF 가 읽는 도메인 파일에 반영한다.
///
/// 왜 두 개인가 (ADR: 도메인 평면 분리):
///   - **DDS 평면**([ddsDomain] → `DDS_DOMAIN_ID`): 순수 Fast-DDS 로 말하는 MMF 버스 —
///     ota_mgr·ota_client·lifecycle_mgr·diagnostics·adsw_manager. raw Fast-DDS 는
///     `ROS_DOMAIN_ID` 를 **보지 않는다**.
///   - **ROS2 평면**([rosDomain] → `ROS_DOMAIN_ID`): rmw/rclcpp 가 읽는 도메인 —
///     rviz2·Autoware·rosbridge.
///   두 평면을 넘나드는 통신은 `dds_bridge` 가 잇는다 — 브릿지가 평면마다 참가자를
///   하나씩 만들어 양쪽에 동시에 존재하고, 리스너 콜백에서 샘플을 반대 평면으로
///   넘긴다(MMF 2026-09-04~). 두 값이 같으면 브릿지는 참가자 하나로 동작한다.
///
/// ⚠ 분리 운영의 전제: ① 이중 도메인 브릿지가 든 ext-ros2 이미지 ② 브릿지가 중계하는
///   토픽만 평면을 넘는다(중계 목록 밖 토픽은 조용히 안 온다). 구버전 ext-ros2 에서
///   값을 나누면 MMF 의 ROS-정규 토픽이 DDS 평면에 실려 HMI 가 데이터를 전부 잃는다
///   — 151 보드 실측 2026-09-04.
///
/// 쓰는 곳 두 군데:
///   1. `<storageDir>/dds_domain.json` — 런처 자신의 설정(재부팅 후에도 유지)
///   2. 도메인 파일 — `DDS_DOMAIN_ID=<n>` + `ROS_DOMAIN_ID=<m>` 두 줄.
///      MMF run 스크립트/compose 가 읽는다.
///
/// ⚠️ 두 도메인 모두 **프로세스 시작 시점에만** 읽힌다 → 값 변경은 해당 서비스가
/// 재기동될 때 반영된다. 실행 중 노드의 도메인을 바꾸는 방법은 존재하지 않는다.
/// ⚠️ 호스트가 여러 대면(HMI 보드 + 차량 컴퓨트) 런처는 **자신이 도는 호스트의 파일만**
/// 갱신한다. 다른 호스트에는 같은 값을 별도로 provisioning 해야 한다.
///
/// I/O 는 주입받는다([TimezoneStore] 와 동일 관례) — 테스트는 [inMemory] 를 쓴다.
class DomainStore extends ChangeNotifier {
  DomainStore({
    required Future<String?> Function() readRaw,
    required Future<void> Function(String content) writeRaw,
    required Future<void> Function(String content) writeEnv,
    this.envFilePath = kDefaultDomainEnvFile,
    int? initialDdsDomain,
    int? initialRosDomain,
  })  : _readRaw = readRaw,
        _writeRaw = writeRaw,
        _writeEnv = writeEnv,
        _ddsDomain = _sanitize(initialDdsDomain, kDefaultDdsDomain),
        _rosDomain = _sanitize(initialRosDomain, kDefaultRosDomain);

  /// 런처 설정 JSON 은 `<storageDir>/dds_domain.json`, 도메인 파일은 [envFilePath].
  factory DomainStore.file(String storageDir, {String? envFilePath}) {
    final path = '$storageDir/dds_domain.json';
    final envPath = envFilePath ?? kDefaultDomainEnvFile;
    return DomainStore(
      readRaw: () async {
        final f = File(path);
        if (!await f.exists()) return null;
        return f.readAsString();
      },
      writeRaw: (content) async {
        final f = File(path);
        await f.parent.create(recursive: true);
        await f.writeAsString(content);
      },
      writeEnv: (content) async {
        final f = File(envPath);
        await f.parent.create(recursive: true);
        await f.writeAsString(content);
      },
      envFilePath: envPath,
    );
  }

  /// 테스트용 — 파일 I/O 없이 메모리에만 보관한다.
  factory DomainStore.inMemory({int? initialDdsDomain, int? initialRosDomain}) {
    String? stored;
    String? env;
    return DomainStore(
      readRaw: () async => stored,
      writeRaw: (content) async => stored = content,
      writeEnv: (content) async => env = content,
      initialDdsDomain: initialDdsDomain,
      initialRosDomain: initialRosDomain,
    )..debugEnvSnapshot = () => env;
  }

  final Future<String?> Function() _readRaw;
  final Future<void> Function(String content) _writeRaw;
  final Future<void> Function(String content) _writeEnv;

  /// MMF 가 기동 시 읽는 도메인 파일 경로 (UI 표시용).
  final String envFilePath;

  /// 테스트가 도메인 파일 내용을 확인할 때 쓰는 훅([inMemory] 에서만 설정된다).
  String? Function()? debugEnvSnapshot;

  int _ddsDomain;
  int _rosDomain;

  /// 순수 DDS(MMF 버스) 도메인 — `DDS_DOMAIN_ID`.
  int get ddsDomain => _ddsDomain;

  /// ROS2(rmw) 도메인 — `ROS_DOMAIN_ID`.
  int get rosDomain => _rosDomain;

  /// 두 평면이 갈라져 있는지. UI 가 "브릿지 경유만 통신됨" 안내를 띄우는 근거.
  bool get isSplit => _ddsDomain != _rosDomain;

  /// 마지막 도메인 파일 쓰기 성공 여부. null = 아직 시도 안 함.
  bool? get lastEnvWriteOk => _lastEnvWriteOk;
  bool? _lastEnvWriteOk;

  /// 도메인 파일 쓰기 실패 이유(권한/경로). 성공이면 null.
  String? get lastEnvError => _lastEnvError;
  String? _lastEnvError;

  static int _sanitize(int? v, int fallback) => isValidDomainId(v) ? v! : fallback;

  /// 도메인 ID 유효성 — 두 평면 공통 규칙.
  static bool isValidDomainId(int? v) =>
      v != null && v >= kMinDomainId && v <= kMaxDomainId;

  /// 저장된 값을 읽어 온다. 없거나 깨졌으면 기본값을 유지한다(경계 방어).
  ///
  /// 구 포맷(`{"domain": n}` — 두 평면이 하나였던 시절)은 **두 값 모두 n** 으로 읽어
  /// 업그레이드 직후 동작이 바뀌지 않게 한다.
  Future<void> load() async {
    try {
      final raw = await _readRaw();
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final legacy = decoded['domain'];
      final dds = decoded['dds_domain'] ?? legacy;
      final ros = decoded['ros_domain'] ?? legacy;
      var changed = false;
      if (dds is int && isValidDomainId(dds)) {
        _ddsDomain = dds;
        changed = true;
      }
      if (ros is int && isValidDomainId(ros)) {
        _rosDomain = ros;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (_) {
      // 손상된 설정 파일 → 기본값으로 계속.
    }
  }

  /// 도메인을 바꾸고 런처 설정 + MMF 도메인 파일에 기록한다.
  ///
  /// 생략한 평면은 현재 값을 유지한다. 범위를 벗어난 값이 하나라도 있으면 아무것도
  /// 바꾸지 않고 false — 절반만 적용된 상태를 만들지 않는다.
  ///
  /// 도메인 파일 쓰기가 실패해도(권한 등) 런처 설정은 저장되고 true 를 돌려주며,
  /// 실패는 [lastEnvWriteOk]/[lastEnvError] 로 노출한다 — 설정 화면이 멈추지 않게
  /// 하면서 실패를 삼키지도 않는다.
  Future<bool> select({int? dds, int? ros}) async {
    final nextDds = dds ?? _ddsDomain;
    final nextRos = ros ?? _rosDomain;
    if (!isValidDomainId(nextDds) || !isValidDomainId(nextRos)) return false;
    _ddsDomain = nextDds;
    _rosDomain = nextRos;
    try {
      await _writeRaw(jsonEncode({
        'dds_domain': _ddsDomain,
        'ros_domain': _rosDomain,
      }));
    } catch (_) {
      // 설정 파일 저장 실패 — 이번 세션 값은 유지한다.
    }
    try {
      await _writeEnv(_renderEnv());
      _lastEnvWriteOk = true;
      _lastEnvError = null;
    } catch (e) {
      _lastEnvWriteOk = false;
      _lastEnvError = e.toString();
    }
    notifyListeners();
    return true;
  }

  /// 도메인 파일 본문. compose `--env-file` 과 같은 `KEY=VALUE` 형식이어야 한다.
  String _renderEnv() =>
      '# hmi_launcher Settings 가 관리하는 MMF 도메인 (두 평면).\n'
      '# 변경은 각 서비스 재기동 시 반영된다 (도메인은 시작 시에만 읽힘).\n'
      '#\n'
      '# $kDdsDomainEnvKey  : 순수 Fast-DDS 버스 — ota/lifecycle/diagnostics/adsw.\n'
      '# $kRosDomainEnvKey  : ROS2(rmw) — rviz2/Autoware/rosbridge.\n'
      '$kDdsDomainEnvKey=$_ddsDomain\n'
      '$kRosDomainEnvKey=$_rosDomain\n';
}
