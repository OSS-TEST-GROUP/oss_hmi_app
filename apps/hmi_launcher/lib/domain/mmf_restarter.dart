import 'dart:io';

/// 도메인을 바꾼 뒤 **같은 호스트의** MMF 컨테이너에 새 도메인이 적용됐는지 확인하고,
/// 적용 가능한 경우에만 재시작한다.
///
/// 왜 단순 재시작으로는 부족한가 (실측 2026-08-04):
///   `docker restart` 는 **컨테이너 생성 당시의 env 를 그대로 재사용**한다. ROS_DOMAIN_ID
///   는 컨테이너 생성 시점에 `run-mmf.sh` / `run-ext-agl.sh` / compose 가 주입하므로,
///   도메인 파일만 바꾸고 restart 해도 프로세스는 **옛 도메인**으로 다시 올라온다.
///   `--restart unless-stopped` 정책 때문에 재부팅해도 같은 컨테이너가 그대로 복귀한다.
///   → 새 도메인을 적용하려면 컨테이너 **재생성**(stop+rm+run)이 필요하다. 그 일은
///   호스트의 run 스크립트/compose 가 한다(둘 다 도메인 파일을 읽는다).
///
/// 그래서 이 클래스는 "재시작했다"고 넘기지 않고, 컨테이너의 현재 ROS_DOMAIN_ID 를 읽어
/// 목표 도메인과 비교한 뒤 [RestartOutcome.needsRecreate] 로 **사실을 그대로 보고**한다.
/// UI 는 그 결과로 사용자에게 무엇을 해야 하는지 알려준다.
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
  static const String kRecreateHint = 'bash /opt/adsw/run-ext-agl.sh';

  final ProcessRunner _run;

  /// 확인/재시작 대상 컨테이너 이름 목록.
  final List<String> containers;

  static Future<ProcessResult> _defaultRunner(String exe, List<String> args) =>
      Process.run(exe, args);

  /// 대상 컨테이너들을 [desiredDomain] 기준으로 점검·재시작하고 결과를 돌려준다.
  Future<Map<String, RestartOutcome>> applyDomain(int desiredDomain) async {
    final result = <String, RestartOutcome>{};
    for (final name in containers) {
      result[name] = await apply(name, desiredDomain);
    }
    return result;
  }

  /// 컨테이너 하나를 점검한다.
  ///
  /// - 없거나 정지 상태 → [RestartOutcome.skipped]
  /// - 컨테이너의 ROS_DOMAIN_ID 가 목표와 다르면(또는 없으면) → [RestartOutcome.needsRecreate]
  ///   (restart 로는 못 바꾸므로 **시도하지 않는다** — 서비스만 끊길 뿐이다)
  /// - 이미 목표 도메인이면 새 설정을 확실히 물리도록 restart → [RestartOutcome.restarted]
  Future<RestartOutcome> apply(String name, int desiredDomain) async {
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
    final current = _domainFromEnv(env);
    if (current != desiredDomain) {
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

  /// `ROS_DOMAIN_ID=<n>` 을 env 문자열에서 뽑는다. 없으면 null.
  static int? _domainFromEnv(String env) {
    for (final kv in env.split(' ')) {
      if (kv.startsWith('ROS_DOMAIN_ID=')) {
        return int.tryParse(kv.substring('ROS_DOMAIN_ID='.length).trim());
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
