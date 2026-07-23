// IDL ↔ wire constants for the rviz2_monitor subset of lifecycle_mgr topics.
//
// Topic strings are the DDS topic names, exposed by dds_bridge as
// ROS-canonical topics (rt/<topic>) on the rosbridge_server side. Type strings
// are ROS msg names from the `lifecyclemgr` ament package.
//
// rviz2_monitor only uses the container-control subset of the full
// LifecycleTopics/LifecycleTypes surface (see lfc_monitor/data/lifecycle_data.dart
// for the complete reference). Update here if the IDL changes.

/// Topic name constants for the rviz2_monitor subset.
class Rviz2Topics {
  // Subscribe (adsw_manager/lifecycle_mgr → monitor)
  static const String notifyContainerState =
      '/mmf/lifecyclemgr/NotifyContainerState';
  static const String diagReport = '/mmf/lifecyclemgr/LifecycleDiagReport';
  static const String ctrlStartContainerResp =
      '/mmf/lifecyclemgr/ctrl/StartContainerResponse';
  static const String ctrlStopContainerResp =
      '/mmf/lifecyclemgr/ctrl/StopContainerResponse';

  // Publish (monitor → lifecycle_mgr ctrl gate)
  static const String ctrlStartContainerReq =
      '/mmf/lifecyclemgr/ctrl/StartContainer';
  static const String ctrlStopContainerReq =
      '/mmf/lifecyclemgr/ctrl/StopContainer';
}

/// ROS message type strings for the rviz2_monitor subset.
class Rviz2Types {
  static const String notifyContainerState = 'lifecyclemgr/NotifyContainerState';
  static const String diagReport = 'lifecyclemgr/LifecycleDiagReport';
  static const String ctrlStartContainerReq =
      'lifecyclemgr/CtrlStartContainerRequest';
  static const String ctrlStopContainerReq =
      'lifecyclemgr/CtrlStopContainerRequest';
  // Both StartContainerResponse and StopContainerResponse share the
  // CtrlResponse IDL struct.
  static const String ctrlResponse = 'lifecyclemgr/CtrlResponse';
  // /rosout
  static const String rosoutLog = 'rcl_interfaces/msg/Log';
}

// Container state enum — declaration-order matches IDL (LifecycleCommon.idl).
// Keep in lockstep with lfc_monitor's ContainerState; a mismatch results in
// mis-labeled badge text only (no crash).
enum ContainerState {
  unknownState, // 0 (CS_UNKNOWN)
  stopped,      // 1 (CONTAINER_STOPPED)
  running,      // 2 (CONTAINER_RUNNING)
  paused;       // 3 (CONTAINER_PAUSED)

  static ContainerState fromInt(int? v) {
    switch (v) {
      case 1:
        return ContainerState.stopped;
      case 2:
        return ContainerState.running;
      case 3:
        return ContainerState.paused;
      default:
        return ContainerState.unknownState;
    }
  }

  String get label {
    switch (this) {
      case ContainerState.unknownState:
        return 'UNKNOWN';
      case ContainerState.stopped:
        return 'STOPPED';
      case ContainerState.running:
        return 'RUNNING';
      case ContainerState.paused:
        return 'PAUSED';
    }
  }
}

/// Lightweight snapshot of the rviz2 container observed via
/// NotifyContainerState and LifecycleDiagReport.
class ContainerInfo {
  ContainerInfo({
    required this.name,
    this.state = ContainerState.unknownState,
    this.exitCode,
    this.lastChangedAt,
  });

  final String name;
  ContainerState state;
  int? exitCode;
  DateTime? lastChangedAt;
}

/// A single /rosout log line filtered from the rviz2 node.
///
/// [level] maps to rcl_interfaces/msg/Log constants:
///   DEBUG=10, INFO=20, WARN=30, ERROR=40, FATAL=50.
/// [name] is the fully-qualified ROS node name (e.g. "/rviz2").
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
  String get levelLabel {
    if (level >= 50) return 'FATAL';
    if (level >= 40) return 'ERROR';
    if (level >= 30) return 'WARN';
    if (level >= 20) return 'INFO';
    return 'DEBUG';
  }
}
