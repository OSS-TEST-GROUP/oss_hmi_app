import 'dart:core';

/// Runtime config for rviz2_monitor — direct docker control variant.
///
/// Loaded from config/config.json next to the binary (see config_loader.dart).
/// Replaces the old rosbridge-based shape with docker + agl-shell parameters.
class AppConfig {
  AppConfig({
    required this.containerName,
    required this.image,
    required this.aglOutput,
    required this.rvizAppId,
    required this.homeAppId,
    required this.pollIntervalSec,
    required this.dockerRunArgs,
  });

  /// Docker container name (used for docker run --name, docker stop, inspect).
  final String containerName;

  /// Full image reference pulled/run by `docker run`.
  final String image;

  /// Wayland output name passed to agl-shell-activator -o.
  final String aglOutput;

  /// AGL surface/process name for the rviz2 cage surface (--p flag).
  final String rvizAppId;

  /// AGL surface/process name for the home launcher (--p flag).
  final String homeAppId;

  /// How often (seconds) [refreshStatus] polls docker inspect.
  final int pollIntervalSec;

  /// Extra `docker run` args inserted between `docker run -d --name <n>` and
  /// the image name.  Each element is a separate shell token (no quoting
  /// needed).  The list is extended at runtime with user-supplied options
  /// (e.g. `-e ROS_DOMAIN_ID=<val>`) before the image name is appended.
  final List<String> dockerRunArgs;

  factory AppConfig.defaults() => AppConfig(
        containerName: 'rviz2',
        // :latest = 레지스트리 런타임 기본 태그(= :autoware 와 동일 이미지: 터치본 + Autoware
        // msgs/rviz 플러그인 오버레이 + cyclonedds). push 규약상 rviz2 이미지는 :latest 로 올린다
        // (+ :autoware/:YYYYMMDD 스냅샷). 특정 변형 필요 시 config.json 에서 image 오버라이드.
        image: 'registry.obigo.com/oss/rviz2-agl:latest',
        aglOutput: 'DP-1',
        rvizAppId: 'wlroots',
        homeAppId: 'hmi_launcher',
        pollIntervalSec: 3,
        dockerRunArgs: const [
          '--net=host',
          '--ipc=host',
          '--user', '1001:1001',
          '--group-add', '44',
          '-v', '/run/user/1001:/host-xdg',
          '-e', 'XDG_RUNTIME_DIR=/host-xdg',
          '-e', 'WAYLAND_DISPLAY=wayland-0',
          '-e', 'HOME=/tmp',
          '-e', 'LIBGL_ALWAYS_SOFTWARE=1',
        ],
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        containerName: (j['containerName'] as String?) ?? 'rviz2',
        image: (j['image'] as String?) ??
            'registry.obigo.com/oss/rviz2-agl:latest',
        aglOutput: (j['aglOutput'] as String?) ?? 'DP-1',
        rvizAppId: (j['rvizAppId'] as String?) ?? 'wlroots',
        homeAppId: (j['homeAppId'] as String?) ?? 'hmi_launcher',
        pollIntervalSec: (j['pollIntervalSec'] as num?)?.toInt() ?? 3,
        dockerRunArgs: (j['dockerRunArgs'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            AppConfig.defaults().dockerRunArgs,
      );
}
