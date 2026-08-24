// Data models for rviz2_panel — direct docker control variant.
//
// All rosbridge / lifecycle_mgr IDL constants have been removed.
// Container state is now polled directly via `docker inspect`.

/// Docker container state as reported by `docker inspect -f '{{.State.Status}}'`.
/// "notInstalled" is a synthetic state when `docker inspect` itself fails
/// (image not pulled or container never created).
enum ContainerState {
  notInstalled, // docker inspect returned non-zero / container unknown
  created,      // container exists but was never started
  running,      // container is up
  exited;       // container stopped (may have non-zero ExitCode)

  /// Map the raw docker inspect Status string to the enum.
  static ContainerState fromDockerStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'running':
        return ContainerState.running;
      case 'created':
        return ContainerState.created;
      case 'exited':
      case 'dead':
      case 'removing':
        return ContainerState.exited;
      default:
        return ContainerState.notInstalled;
    }
  }

  /// Badge label shown in the UI.
  String get label {
    switch (this) {
      case ContainerState.notInstalled:
        return 'NOT INSTALLED';
      case ContainerState.created:
        return 'CREATED';
      case ContainerState.running:
        return 'RUNNING';
      case ContainerState.exited:
        return 'STOPPED';
    }
  }
}

/// Lightweight snapshot of the rviz2 container observed via
/// `docker inspect` polling.
class ContainerInfo {
  ContainerInfo({
    required this.name,
    this.state = ContainerState.notInstalled,
    this.exitCode,
    this.lastChangedAt,
  });

  final String name;
  ContainerState state;

  /// Last known exit code from docker inspect `{{.State.ExitCode}}`.
  /// Null when not yet inspected or container is running.
  int? exitCode;

  DateTime? lastChangedAt;
}

/// A single log line from `docker logs` (stdout or stderr).
///
/// [level] is synthetic: 40 = stderr, 20 = stdout.
/// [name] is always the container name.
class LogLine {
  LogLine({
    required this.level,
    required this.name,
    required this.msg,
    required this.ts,
  });

  final int level;
  final String name;
  final String msg;
  final DateTime ts;

  /// Human-readable level abbreviation for the log badge.
  /// 로그 배지 라벨. 컨테이너의 stderr 대부분이 정상 정보라서(homebar 상태 출력,
  /// wlroots/XWayland [DEBUG], ROS [INFO]) 스트림이 아니라 **레벨**로 표기한다 —
  /// 레벨 판정은 Rviz2Controller._levelFor 가 내용으로 수행한다.
  String get levelLabel {
    if (level >= 40) return 'ERR';
    if (level >= 30) return 'WARN';
    return 'OUT';
  }
}
