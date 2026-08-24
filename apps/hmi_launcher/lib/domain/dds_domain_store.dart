import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// ROS 2 / Fast-DDS 도메인 ID 유효 범위 (rmw 제약).
const int kMinDdsDomain = 0;
const int kMaxDdsDomain = 232;

/// 기본 도메인 **42** — 151 보드의 Autoware adsw 파티션(saved-service-list.yaml)이 42 다.
/// MMF 기본이 0 이던 동안 adsw_monitor 는 구독만 하고 발행자가 없어 화면이 전부 `null`
/// 이었다(실측 2026-08-04: domain 0 의 `/api/vehicle/status` Publisher count 0).
const int kDefaultDdsDomain = 42;

/// MMF 서비스가 기동 시 읽는 도메인 파일 기본 경로.
/// `run-mmf.sh`(core+ext-ros2) / `run-ext-agl.sh` / docker compose(`--env-file`) 공통.
const String kDefaultDomainEnvFile = '/opt/mmf/config/domain.env';

/// 사용자가 고른 DDS 도메인을 보관하고, MMF 가 읽는 도메인 파일에 반영한다.
///
/// 쓰는 곳 두 군데:
///   1. `<storageDir>/dds_domain.json` — 런처 자신의 설정(재부팅 후에도 유지)
///   2. 도메인 파일 — `ROS_DOMAIN_ID=<n>`. MMF run 스크립트/compose 가 읽는다.
///
/// ⚠️ `ROS_DOMAIN_ID` 는 **프로세스 시작 시점에만** 읽힌다 → 값 변경은 해당 서비스가
/// 재기동될 때 반영된다. 실행 중 노드의 도메인을 바꾸는 방법은 존재하지 않는다.
/// ⚠️ 호스트가 여러 대면(HMI 보드 + 차량 컴퓨트) 런처는 **자신이 도는 호스트의 파일만**
/// 갱신한다. 다른 호스트에는 같은 값을 별도로 provisioning 해야 한다.
///
/// I/O 는 주입받는다([TimezoneStore] 와 동일 관례) — 테스트는 [inMemory] 를 쓴다.
class DdsDomainStore extends ChangeNotifier {
  DdsDomainStore({
    required Future<String?> Function() readRaw,
    required Future<void> Function(String content) writeRaw,
    required Future<void> Function(String content) writeEnv,
    this.envFilePath = kDefaultDomainEnvFile,
    int? initialDomain,
  })  : _readRaw = readRaw,
        _writeRaw = writeRaw,
        _writeEnv = writeEnv,
        _domain = _sanitize(initialDomain);

  /// 런처 설정 JSON 은 `<storageDir>/dds_domain.json`, 도메인 파일은 [envFilePath].
  factory DdsDomainStore.file(String storageDir, {String? envFilePath}) {
    final path = '$storageDir/dds_domain.json';
    final envPath = envFilePath ?? kDefaultDomainEnvFile;
    return DdsDomainStore(
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
  factory DdsDomainStore.inMemory({int? initialDomain}) {
    String? stored;
    String? env;
    return DdsDomainStore(
      readRaw: () async => stored,
      writeRaw: (content) async => stored = content,
      writeEnv: (content) async => env = content,
      initialDomain: initialDomain,
    )..debugEnvSnapshot = () => env;
  }

  final Future<String?> Function() _readRaw;
  final Future<void> Function(String content) _writeRaw;
  final Future<void> Function(String content) _writeEnv;

  /// MMF 가 기동 시 읽는 도메인 파일 경로 (UI 표시용).
  final String envFilePath;

  /// 테스트가 도메인 파일 내용을 확인할 때 쓰는 훅([inMemory] 에서만 설정된다).
  String? Function()? debugEnvSnapshot;

  int _domain;

  /// 현재 선택된 도메인.
  int get domain => _domain;

  /// 마지막 도메인 파일 쓰기 성공 여부. null = 아직 시도 안 함.
  bool? get lastEnvWriteOk => _lastEnvWriteOk;
  bool? _lastEnvWriteOk;

  /// 도메인 파일 쓰기 실패 이유(권한/경로). 성공이면 null.
  String? get lastEnvError => _lastEnvError;
  String? _lastEnvError;

  static int _sanitize(int? v) =>
      (v != null && v >= kMinDdsDomain && v <= kMaxDdsDomain)
          ? v
          : kDefaultDdsDomain;

  /// 저장된 값을 읽어 온다. 없거나 깨졌으면 기본값을 유지한다(경계 방어).
  Future<void> load() async {
    try {
      final raw = await _readRaw();
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['domain'] is int) {
        final v = decoded['domain'] as int;
        if (v >= kMinDdsDomain && v <= kMaxDdsDomain) {
          _domain = v;
          notifyListeners();
        }
      }
    } catch (_) {
      // 손상된 설정 파일 → 기본값으로 계속.
    }
  }

  /// 도메인을 바꾸고 런처 설정 + MMF 도메인 파일에 기록한다.
  ///
  /// 범위를 벗어나면 아무것도 하지 않고 false. 도메인 파일 쓰기가 실패해도(권한 등)
  /// 런처 설정은 저장되고 true 를 돌려주며, 실패는 [lastEnvWriteOk]/[lastEnvError]
  /// 로 노출한다 — 설정 화면이 멈추지 않게 하면서 실패를 삼키지도 않는다.
  Future<bool> select(int value) async {
    if (value < kMinDdsDomain || value > kMaxDdsDomain) return false;
    _domain = value;
    try {
      await _writeRaw(jsonEncode({'domain': _domain}));
    } catch (_) {
      // 설정 파일 저장 실패 — 이번 세션 값은 유지한다.
    }
    try {
      await _writeEnv(
        '# hmi_launcher Settings 가 관리하는 MMF DDS 도메인.\n'
        '# 변경은 각 서비스 재기동 시 반영된다 (ROS_DOMAIN_ID 는 시작 시에만 읽힘).\n'
        'ROS_DOMAIN_ID=$_domain\n',
      );
      _lastEnvWriteOk = true;
      _lastEnvError = null;
    } catch (e) {
      _lastEnvWriteOk = false;
      _lastEnvError = e.toString();
    }
    notifyListeners();
    return true;
  }
}
