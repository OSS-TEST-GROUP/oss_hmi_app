import 'dart:io';

/// 도메인을 바꾼 뒤 **같은 호스트의** MMF 컨테이너에 새 도메인이 적용됐는지 확인하고,
/// 적용 가능한 경우에만 재시작한다.
///
/// 왜 단순 재시작으로는 부족한가 (실측 2026-08-04):
///   `docker restart` 는 **컨테이너 생성 당시의 env 를 그대로 재사용**한다. 도메인 env
///   는 컨테이너 생성 시점에 `run-mmf.sh` / `run-ext-agl.sh` / compose 가 주입하므로,
///   도메인 파일만 바꾸고 restart 해도 프로세스는 **옛 도메인**으로 다시 올라온다.
///   `--restart unless-stopped` 정책 때문에 재부팅해도 같은 컨테이너가 그대로 복귀한다.
///   → 새 도메인을 적용하려면 컨테이너 **재생성**(stop+rm+run)이 필요하다. 그 일은
///   호스트의 run 스크립트/compose 가 한다(둘 다 도메인 파일을 읽는다).
///
/// 그래서 이 클래스는 "재시작했다"고 넘기지 않고, 컨테이너의 현재 **두 평면**
/// 도메인(DDS/ROS2)을 읽어 목표와 비교한 뒤 [RestartOutcome.needsRecreate] 로
/// **사실을 그대로 보고**한다. UI 는 그 결과로 사용자에게 무엇을 해야 하는지 알려준다.
///
/// 범위: 런처와 같은 호스트의 컨테이너만. 다른 호스트(차량 컴퓨트의 core/ext-ros2)는
/// 그 호스트에서 재생성해야 한다.
class MmfRestarter {
  MmfRestarter({ProcessRunner? runner, List<String>? containers})
      : _run = runner ?? _defaultRunner,
        containers = containers ?? kDefaultTargets;

  /// 도메인 변경 시 확인할 로컬 컨테이너 (없으면 조용히 건너뛴다).
  static const List<String> kDefaultTargets = ['oss-mmf-ext-agl'];

  /// 재생성이 필요할 때 사용자에게 안내할 호스트 명령.
  ///
  /// `oss-domain-apply` 는 **이 호스트의 플랫폼 컨테이너**(core/ext-ros2/ext-agl)를
  /// 도메인 파일 기준으로 재생성한다. 예전 안내(`run-ext-agl.sh`)는 81 의 ext-agl
  /// 하나만 다뤄서, 151 의 core/ext-ros2 가 옛 도메인에 남고 Autoware 는 그 값을
  /// 물려받아 **몇 번 재시작해도 도메인이 바뀌지 않았다**(보드 실측 2026-09-08, 3회 재현).
  ///
  /// `oss-domain-apply.path` 유닛이 켜져 있으면 도메인 파일이 바뀌는 순간 **각 보드가
  /// 자동으로** 실행하므로 이 명령을 직접 칠 필요가 없다. 이 문구는 그 유닛이 없는
  /// 환경(구 이미지)을 위한 대비책이다.
  static const String kRecreateHint = 'sudo systemctl start oss-domain-apply';

  final ProcessRunner _run;

  /// 확인/재시작 대상 컨테이너 이름 목록.
  final List<String> containers;

  static Future<ProcessResult> _defaultRunner(String exe, List<String> args) =>
      Process.run(exe, args);

  /// 대상 컨테이너들을 두 평면 목표 도메인 기준으로 점검·재시작하고 결과를 돌려준다.
  Future<Map<String, RestartOutcome>> applyDomains({
    required int dds,
    required int ros,
  }) async {
    final result = <String, RestartOutcome>{};
    for (final name in containers) {
      result[name] = await apply(name, dds: dds, ros: ros);
    }
    return result;
  }

  /// 컨테이너 하나를 점검한다.
  ///
  /// - 없거나 정지 상태 → [RestartOutcome.skipped]
  /// - 컨테이너의 DDS/ROS2 도메인 중 **하나라도** 목표와 다르면(또는 없으면)
  ///   → [RestartOutcome.needsRecreate]
  ///   (restart 로는 못 바꾸므로 **시도하지 않는다** — 서비스만 끊길 뿐이다)
  /// - 두 평면 모두 목표와 같으면 새 설정을 확실히 물리도록 restart
  ///   → [RestartOutcome.restarted]
  Future<RestartOutcome> apply(
    String name, {
    required int dds,
    required int ros,
  }) async {
    ProcessResult probe;
    try {
      probe = await _run('docker', [
        'inspect',
        '-f',
        '{{.State.Running}}|{{range .Config.Env}}{{.}} {{end}}',
        name,
      ]);
    } catch (_) {
      return RestartOutcome.unavailable; // docker CLI/소켓 없음
    }
    if (probe.exitCode != 0) return RestartOutcome.skipped; // 그런 컨테이너 없음

    final out = '${probe.stdout}'.trim();
    final parts = out.split('|');
    if (parts.isEmpty || parts.first.trim() != 'true') {
      return RestartOutcome.skipped; // 정지 상태
    }
    final env = parts.length > 1 ? parts[1] : '';
    if (currentDdsDomain(env) != dds || currentRosDomain(env) != ros) {
      // restart 는 옛 env 를 그대로 재사용하므로 의미가 없다 → 사실만 보고.
      return RestartOutcome.needsRecreate;
    }

    try {
      final res = await _run('docker', ['restart', name]);
      return res.exitCode == 0 ? RestartOutcome.restarted : RestartOutcome.failed;
    } catch (_) {
      return RestartOutcome.unavailable;
    }
  }

  /// 컨테이너 env 에서 **DDS 평면** 도메인을 읽는다. 없으면 null.
  ///
  /// 서비스별 override 인 `MMF_DDS_DOMAIN_ID` 를 먼저 본다 — MMF C++ 쪽 우선순위
  /// (`MMF_DDS_DOMAIN_ID` > `DDS_DOMAIN_ID`)와 같은 규칙이어야 판정이 어긋나지 않는다.
  static int? currentDdsDomain(String env) =>
      _valueOf(env, 'MMF_DDS_DOMAIN_ID') ?? _valueOf(env, 'DDS_DOMAIN_ID');

  /// 컨테이너 env 에서 **ROS2 평면** 도메인을 읽는다. 없으면 null.
  static int? currentRosDomain(String env) => _valueOf(env, 'ROS_DOMAIN_ID');

  /// `KEY=<n>` 을 공백으로 이어진 env 문자열에서 뽑는다.
  static int? _valueOf(String env, String key) {
    final prefix = '$key=';
    for (final kv in env.split(' ')) {
      if (kv.startsWith(prefix)) {
        return int.tryParse(kv.substring(prefix.length).trim());
      }
    }
    return null;
  }
}

/// 컨테이너 하나에 대한 처리 결과.
enum RestartOutcome {
  /// 이미 목표 도메인이라 재시작으로 새 설정을 반영했다.
  restarted,

  /// 목표 도메인과 달라 **재생성이 필요**하다 (restart 로는 불가 — env 가 고정됨).
  needsRecreate,

  /// 이 호스트에 없거나 정지 상태라 건너뜀.
  skipped,

  /// docker 를 쓸 수 없는 환경(소켓/CLI 없음).
  unavailable,

  /// docker restart 가 0 이 아닌 코드로 실패.
  failed,
}

/// `Process.run` 시그니처 — 테스트에서 가짜 실행기를 주입한다.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);
