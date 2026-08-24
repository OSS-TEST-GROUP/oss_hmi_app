#!/usr/bin/env python3
"""ROS_DOMAIN_ID 42 → 0 토픽 릴레이 (adsw_monitor 통합 검증용).

왜 필요한가 (실측 2026-08-04):
  - adsw_monitor(hmi_launcher 내장)는 rosbridge `ws://172.16.10.151:9090` 로 붙는다.
    그 rosbridge(oss-mmf-ext-ros2)는 **ROS_DOMAIN_ID=0** (MMF_DDS_DOMAIN_ID=0).
  - 반면 151 의 Autoware adsw 파티션(junohb)은 **ROS_DOMAIN_ID=42** 로 돈다.
  - 그래서 domain 0 에서 adsw_monitor 가 구독하는 토픽은 **Publisher count 0** →
    앱 화면이 전부 `null`. rosbridge 로그에는 구독이 정상 등록돼 있고, domain 0 에
    임의 VelocityReport 를 발행하면 앱이 즉시 값을 표시한다(= 경로는 정상, 발행자만 없음).

이 스크립트는 **검증용 임시 브리지**다. 제품 차원의 해결은 도메인 정렬이다:
  ① Autoware 파티션을 MMF 도메인(0)으로 기동, 또는
  ② MMF(core+ext-ros2)를 Autoware 도메인(42)으로 기동, 또는
  ③ 공식 `domain_bridge` 패키지 도입.
어느 쪽이든 두 팀의 배포 설정 합의가 필요하므로, 그 전까지 이 릴레이로 검증한다.

동작: 같은 프로세스에서 컨텍스트 2개(domain 42 구독 / domain 0 발행)를 만들고
      **직렬화된 바이트를 그대로** 재발행한다(raw) → 메시지 타입에 무관하게 동작.

실행 (보드에서, rviz2 이미지 재사용):
  docker run -d --name adsw-relay --net=host --ipc=host \
    registry.obigo.com/oss/rviz2-agl:latest \
    bash -lc 'source /opt/ros/humble/setup.bash; source /opt/autoware/setup.bash; \
              python3 /relay.py'
  (이미지에 없으면 docker cp 로 넣는다: docker cp adsw-domain-relay.py adsw-relay:/relay.py)
"""
import time

import rclpy
from rclpy.executors import SingleThreadedExecutor
from rclpy.node import Node
from rclpy.qos import QoSProfile, DurabilityPolicy, HistoryPolicy, ReliabilityPolicy
from rosidl_runtime_py.utilities import get_message

SRC_DOMAIN = 42          # Autoware(junohb adsw 파티션)
DST_DOMAIN = 0           # MMF ext-ros2 rosbridge

# adsw_monitor 가 구독하는 토픽 (apps/adsw_monitor/lib/data/adsw_data.dart).
# /map/pointcloud_map 은 수십 MB 라 제외(앱은 height/width 만 쓰지만 릴레이 비용이 큼).
TOPICS = [
    '/api/vehicle/status',
    '/api/perception/objects',
    '/localization/kinematic_state',
    '/vehicle/status/velocity_status',
    '/vehicle/status/battery_charge',
    '/perception/traffic_light_recognition/judged/traffic_signals',
    '/planning/path_candidate/goal_planner',
    '/sensing/imu/imu_data',
    '/sensing/number_of_sensor',
    '/diagnostics',
]


def make_ctx(domain: int):
    """지정 도메인의 rclpy 컨텍스트를 만든다 (도메인은 컨텍스트 단위 설정)."""
    ctx = rclpy.Context()
    rclpy.init(context=ctx, domain_id=domain)
    return ctx


def resolve_types(node: Node, wanted: list[str], timeout_s: float = 20.0) -> dict[str, str]:
    """구독 대상 토픽의 실제 타입을 그래프에서 찾는다(발행 중인 것만 릴레이 가능)."""
    found: dict[str, str] = {}
    deadline = time.time() + timeout_s
    while time.time() < deadline and len(found) < len(wanted):
        for name, types in node.get_topic_names_and_types():
            if name in wanted and name not in found and types:
                found[name] = types[0]
        if len(found) < len(wanted):
            time.sleep(1.0)
    return found


def main() -> None:
    src_ctx, dst_ctx = make_ctx(SRC_DOMAIN), make_ctx(DST_DOMAIN)
    src = rclpy.create_node('adsw_relay_src', context=src_ctx)
    dst = rclpy.create_node('adsw_relay_dst', context=dst_ctx)

    types = resolve_types(src, TOPICS)
    missing = [t for t in TOPICS if t not in types]
    print(f"[relay] domain {SRC_DOMAIN} → {DST_DOMAIN}: {len(types)}개 릴레이", flush=True)
    if missing:
        print(f"[relay] 발행자 없어 생략: {', '.join(missing)}", flush=True)

    # QoS 는 **양방향 호환이 되는 조합**을 쓴다(실측: 섞이면 "incompatible QoS,
    # No messages will be received" 로 조용히 끊긴다).
    #  - 구독(42): BEST_EFFORT + VOLATILE → reliable/transient_local 발행자도 모두 수용
    #  - 발행(0):  RELIABLE + TRANSIENT_LOCAL → best-effort/volatile 구독자도 모두 수용,
    #             게다가 늦게 붙는 rosbridge·앱이 마지막 값을 즉시 받는다.
    sub_qos = QoSProfile(depth=5, history=HistoryPolicy.KEEP_LAST,
                         reliability=ReliabilityPolicy.BEST_EFFORT,
                         durability=DurabilityPolicy.VOLATILE)
    pub_qos = QoSProfile(depth=5, history=HistoryPolicy.KEEP_LAST,
                         reliability=ReliabilityPolicy.RELIABLE,
                         durability=DurabilityPolicy.TRANSIENT_LOCAL)

    pubs = {}
    for topic, type_str in types.items():
        msg_cls = get_message(type_str)
        pubs[topic] = dst.create_publisher(msg_cls, topic, pub_qos)
        # raw=True → 역직렬화 없이 바이트 그대로 받아 그대로 재발행(타입 무관, CPU 절약).
        src.create_subscription(
            msg_cls, topic,
            (lambda t: lambda data: pubs[t].publish(data))(topic),
            sub_qos, raw=True,
        )
        print(f"[relay]   {topic}  ({type_str})", flush=True)

    # ⚠️ rclpy.spin*() 는 **기본 컨텍스트**의 전역 executor 를 쓴다. 여기선 기본
    # 컨텍스트를 init 하지 않으므로(도메인별 컨텍스트만 씀) AttributeError 가 난다(실측).
    # 소스 컨텍스트에 묶인 executor 를 직접 만들어 돌린다.
    executor = SingleThreadedExecutor(context=src_ctx)
    executor.add_node(src)
    try:
        executor.spin()
    except KeyboardInterrupt:
        pass
    finally:
        executor.shutdown()
        src.destroy_node()
        dst.destroy_node()
        rclpy.shutdown(context=src_ctx)
        rclpy.shutdown(context=dst_ctx)


if __name__ == '__main__':
    main()
