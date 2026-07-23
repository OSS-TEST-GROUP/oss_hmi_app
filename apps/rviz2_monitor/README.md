# rviz2_monitor — RViz2 Monitor

RViz2 컨테이너의 **상태 모니터링 · 실행옵션 설정 · start/stop 제어 · 로그 표시**를 제공하는
HMI (rosbridge 경유). 런처 카드 "RViz2 Monitor"(🤖). 단독 실행 또는 hmi_launcher 에 임베드.

## 개요

- **상태 모니터링**: `NotifyContainerState` + `LifecycleDiagReport` 구독 → rviz2 컨테이너의
  RUNNING/STOPPED/exit_code/lastChanged 표시
- **start/stop 제어**: `ctrl/StartContainer`/`ctrl/StopContainer` publish (container_list=["rviz2"])
  → lifecycle_mgr 정책 게이트 → adsw_manager → `docker run/stop`
- **실행 옵션 (v1)**: `.rviz` 설정 파일 경로, `ROS_DOMAIN_ID`, GPU 모드(SW/HW) — 로컬 상태 유지
- **로그 표시**: `/rosout` 구독 → rviz2 노드 이름 필터 → 스크롤 로그 뷰

## 배경

rviz2 렌더링(cage surface)은 Flutter 임베드 불가(ADR-014) → **제어판을 임베드**하는 우회.
adsw_manager 레지스트리에 `recovery_policy=MANUAL + init_state=NOT_RUNNING` 으로 등록되어
ext-agl 자동실행/복구는 안 하고, start/stop 은 rviz2_monitor 가 트리거.

## 설정 (config/config.json)

- `rosbridge.url` (기본 `ws://127.0.0.1:9090`)
- `containerName` (기본 `rviz2`) — ctrl 대상 컨테이너 이름
- `rosoutTopic` (기본 `/rosout`) — /rosout 구독 토픽
- `pollIntervalSec` (기본 5)

## Standalone 빌드

```bash
# 상위 docker build 워크플로우와 동일 (oss_hmi_app apps/ 참조)
flutter build linux --release
```

## 관련

- F010 설계 문서: `rviz2_agent/docs/design/F010-rviz2-monitor.md`
- ADR-014: RViz2 렌더링 임베드 불가 판정
- lfc_monitor: 동일 패턴의 lifecycle 모니터 (템플릿)
