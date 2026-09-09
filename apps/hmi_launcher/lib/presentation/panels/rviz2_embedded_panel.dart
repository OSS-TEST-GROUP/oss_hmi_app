import 'package:flutter/material.dart';
import 'package:rviz2_panel/main.dart' as rviz2;

/// Embeds the RViz2 Monitor inside hmi_launcher.
///
/// Unlike the other monitor panels (lfc/adsw/ota), rviz2_panel does NOT use
/// rosbridge / lifecycle_mgr. It controls the local rviz2 docker container
/// directly (docker CLI via the mounted docker.sock) and switches the screen
/// via the AGL shell gRPC service (:14005) — so it takes no rosUrl.
///
/// 설정은 rviz2_panel 의 **단독 실행과 동일한 로더**(`loadConfig`)로 읽는다:
/// `RVIZ2_MONITOR_CONFIG` env → ./config/config.json → ~/.config/rviz2_panel/config.json
/// → /etc/rviz2_panel/config.json → 없으면 `AppConfig.defaults()`.
/// 보드(AGL)는 아무것도 마운트하지 않아 defaults 를 그대로 쓰므로 동작이 바뀌지 않고,
/// x86 개발 PC 처럼 **이미지/`docker run` 인자가 다른 환경**에서는 설정 파일 하나로
/// 맞출 수 있다(이전에는 defaults 가 하드코딩돼 우회가 불가능했다).
class Rviz2EmbeddedPanel extends StatefulWidget {
  const Rviz2EmbeddedPanel({super.key, this.domainId});

  /// 런처 Settings 의 **ROS domain** 값. rviz2 컨테이너의 `ROS_DOMAIN_ID` 프리필로
  /// 내려간다 — rviz2·Autoware·rosbridge 가 같은 ROS2 도메인이어야 통신하므로 설정을
  /// 한 곳에서 관리한다. null 이면 설정 파일/기본값의 도메인을 그대로 쓴다.
  final String? domainId;

  @override
  State<Rviz2EmbeddedPanel> createState() => _Rviz2EmbeddedPanelState();
}

class _Rviz2EmbeddedPanelState extends State<Rviz2EmbeddedPanel> {
  /// 설정 로드는 한 번만 (build 마다 파일을 다시 읽지 않도록 State 에 보관).
  late final Future<rviz2.AppConfig> _cfg = _load();

  Future<rviz2.AppConfig> _load() async {
    // 단독 실행과 같은 탐색 순서. 파일이 없으면 loadConfig 가 defaults 를 돌려준다.
    final cfg = await rviz2.loadConfig(const <String>[]);
    return cfg.withDomainId(widget.domainId);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: FutureBuilder<rviz2.AppConfig>(
        future: _cfg,
        builder: (context, snap) {
          // ⚠️ 로드 전에 defaults 로 한 번 그리면 안 된다 — Rviz2ViewPage 는 initState 에서
          //    cfg 를 컨트롤러로 복사하므로, 나중에 설정이 도착해도 위젯만 갱신되고
          //    **컨트롤러는 defaults 를 계속 쓴다**(실측: 설정 파일을 읽었는데도 컨테이너가
          //    보드 기본 인자로 기동). 그래서 데이터가 준비될 때까지 페이지를 만들지 않는다.
          //    파일 읽기는 수 ms 라 사용자가 체감하지 못한다.
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return rviz2.Rviz2ViewPage(cfg: snap.data!, embedded: true);
        },
      ),
    );
  }
}
