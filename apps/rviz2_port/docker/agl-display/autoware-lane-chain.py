#!/usr/bin/env python3
"""Autoware 지도에서 주행 가능한 긴 차선 체인을 찾아 EGO/GOAL 포즈를 뽑는다.

autoware-sim.sh 로 시뮬레이션할 때 "The planned route is empty." 를 피하려면
**Autoware 가 쓰는 lanelet2 라우팅 그래프**의 연결 관계를 따라야 한다. 좌표가
기하적으로 이어져 보여도 lanelet 관계가 없으면 라우팅은 실패한다(실측).

실행 위치: Autoware 컨테이너 안 (lanelet2 python 바인딩 + 지도가 있는 곳).
    docker cp autoware-lane-chain.py autoware-perception:/tmp/
    docker exec autoware-perception bash -lc \
      'source /opt/autoware/setup.bash; python3 /tmp/autoware-lane-chain.py'

출력의 CAND1 EGO/GOAL 을 그대로 autoware-sim.sh 에 넘긴다:
    EGO="3655.152 73490.295 0.981391 0.192022" \
    GOAL="3656.523 73465.238 -0.661011 0.750376" bash autoware-sim.sh

주의: 최장 단순경로는 NP-hard 라 전수 DFS 는 실용적이지 않다(실측: 190 차선에서
타임아웃). 소스 차선마다 "가장 긴 다음 차선"을 고르는 그리디 워크로 충분히 긴
경로를 즉시 얻는다 — 검증 결과 794m / 22 차선.
"""
import math

import lanelet2
from lanelet2.io import Origin, loadRobust
from lanelet2.projection import UtmProjector
from lanelet2.routing import RoutingGraph
from lanelet2.traffic_rules import Locations, Participants, create

MAP_PATH = "/autoware_map/lanelet2_map.osm"
# planning simulator 가 쓰는 지도 원점 (sample-map-planning). 다른 지도면 바꿀 것.
ORIGIN_LAT, ORIGIN_LON = 35.23808753540768, 139.9009591876285
TOP_N = 5


def load_graph():
    """지도를 로드하고 Autoware 와 같은 차량 규칙의 라우팅 그래프를 만든다."""
    projector = UtmProjector(Origin(ORIGIN_LAT, ORIGIN_LON))
    lmap, _ = loadRobust(MAP_PATH, projector)
    rules = create(Locations.Germany, Participants.Vehicle)
    return lmap, RoutingGraph(lmap, rules)


def centerline_length(points) -> float:
    """센터라인 폴리라인의 길이(m)."""
    return sum(
        math.hypot(points[k + 1].x - points[k].x, points[k + 1].y - points[k].y)
        for k in range(len(points) - 1)
    )


def pose_at(points, frac: float):
    """센터라인 위 비율 위치의 (x, y, qz, qw) — 진행 방향을 yaw 로."""
    idx = max(0, min(len(points) - 2, int(frac * (len(points) - 1))))
    yaw = math.atan2(points[idx + 1].y - points[idx].y, points[idx + 1].x - points[idx].x)
    return points[idx].x, points[idx].y, math.sin(yaw / 2), math.cos(yaw / 2)


def greedy_walk(start_id, following, lengths):
    """방문하지 않은 다음 차선 중 가장 긴 것을 계속 따라가 단순경로를 만든다."""
    path = [start_id]
    seen = {start_id}
    dist = lengths[start_id]
    while True:
        nxt = [j for j in following[path[-1]] if j not in seen]
        if not nxt:
            return dist, path
        pick = max(nxt, key=lambda x: lengths[x])
        path.append(pick)
        seen.add(pick)
        dist += lengths[pick]


def main() -> None:
    lmap, graph = load_graph()
    lanes = {l.id: l for l in lmap.laneletLayer}
    centerlines = {i: list(l.centerline) for i, l in lanes.items()}
    lengths = {i: centerline_length(c) for i, c in centerlines.items()}
    following = {i: [f.id for f in graph.following(l)] for i, l in lanes.items()}

    # 소스 = 선행 차선이 없는 차선(경로 시작 후보). 없으면 전체를 후보로.
    has_pred = {j for succ in following.values() for j in succ}
    sources = [i for i in lanes if i not in has_pred] or list(lanes)
    print(f"lanelets={len(lanes)} edges={sum(len(v) for v in following.values())} "
          f"sources={len(sources)}")

    walks = sorted((greedy_walk(s, following, lengths) for s in sources), key=lambda t: -t[0])
    for rank, (dist, path) in enumerate(walks[:TOP_N], 1):
        # 차선 경계에 걸치면 인접 차선으로 스냅될 수 있어 양 끝은 중간쯤을 쓴다.
        ex, ey, ez, ew = pose_at(centerlines[path[0]], 0.3)
        gx, gy, gz, gw = pose_at(centerlines[path[-1]], 0.7)
        print(f"CAND{rank} dist={dist:.0f}m lanes={len(path)} "
              f"start={path[0]} end={path[-1]}")
        print(f'  EGO="{ex:.3f} {ey:.3f} {ez:.6f} {ew:.6f}"')
        print(f'  GOAL="{gx:.3f} {gy:.3f} {gz:.6f} {gw:.6f}"')


if __name__ == "__main__":
    main()
