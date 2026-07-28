# rviz2 AGL-display 컨테이너 (cage 기반) — 현재 정본

> Orin AGX + AGL 순수 Wayland 에서 rviz2 를 실행하는 **컨테이너 격리** 방식. 호스트 AGL
> 이미지는 불변, docker 컨테이너 안에서 rviz2 스택(ROS2 Humble / Qt5 / OGRE) 전체를 격리.
> 2026-07-20 Orin AGX 실기 검증(표출 5/5) + 2026-07-23 입력(XTEST) 검증 완료.

## 구조

```
cage(wlroots 키오스크, app_id="wlroots", wayland 클라이언트 + XWayland 내장)
  └─ rviz2 (Qt5/OGRE → llvmpipe SW-GL)   # OGRE 1.12.1 = rviz-ogre-vendor 번들(별도 OGRE 설치 불필요)
```
- **아키 무관 Dockerfile**: `FROM ros:humble-ros-base` + apt(ros-humble-rviz2 / cage / xwayland). ros:humble 는 멀티아치(amd64+arm64) 베이스라 한 Dockerfile 로 양 아키 빌드.
- cage 채택: weston 9 는 `set_app_id` 미호출 → agl-compositor 활성화 불가. cage 는 app_id="wlroots" 설정 + 단일앱 풀스크린.

## 파일

| 파일 | 역할 |
|---|---|
| `Dockerfile` | rviz2 + cage + xwayland 컨테이너 (아키 무관) |
| `entrypoint.sh` | `cage -- ros2 run rviz2 rviz2` (app_id=wlroots, SW-GL) |
| `run-on-board.sh` | 보드(arm64/AGL) 수동 실행 — 소켓 탐지 + docker run + agl-shell 활성화 |
| `agl-service-list.rviz2.yaml` | ext-agl(adsw_manager) 등재 스니펫 (부팅 자동기동/복구) |

## 빌드 (멀티아치 amd64 + arm64, 원샷)

```bash
cd apps
./docker/script/build_rviz2_multiarch.sh              # → registry.obigo.com/oss/rviz2-agl:latest
TAG=multiarch-verify ./docker/script/build_rviz2_multiarch.sh   # 검증용(:latest 미변경)
```
> Flutter 앱(build_multiarch.sh)과 달리 아키별 번들이 없어 `buildx --platform=amd64,arm64` **한 방**으로 manifest list 생성 (2회 빌드 + imagetools 결합 불필요).

## 런타임

- **arm64 (Orin/AGL — 주 타겟)**: `./run-on-board.sh` (수동) 또는 ext-agl 등재(자동). 표출/홈전환은 agl-shell 스위처(F006, `docs/design/F006-switcher.md`) 가 `agl-shell-activator -a activate -p wlroots` 로 수행.
- **amd64 (x86 dev/CI)**: `bash docker/script/run-rviz2-x86.sh` — 호스트 X11 에 rviz2 직접 실행(cage 우회). `GPU=nvidia|none`.

## 설치 (보드 자동시작 — ext-agl)

`/opt/adsw/config/agl-service-list.yaml` 의 `services:` 에 `agl-service-list.rviz2.yaml` 항목 추가 → adsw_manager 가 rviz2 컨테이너를 기동/복구 관리.

```bash
# 보드에서 (예시)
scp agl-service-list.rviz2.yaml root@<board>:/tmp/
ssh root@<board> 'cat /tmp/agl-service-list.rviz2.yaml >> /opt/adsw/config/agl-service-list.yaml && docker restart oss-mmf-ext-agl'
```
> ⚠️ ext-agl 은 `docker run` 만 하고 **agl-shell 활성화는 안 함** → rviz2 는 기동되지만 비활성(비표출). 표출은 F006 스위처가 담당(상시기동 + activate-swap 모델).

## GPU 가속 (F008, 선택)

현재 llvmpipe(SW, ~30fps). 런처가 쓰는 `/opt/nv-gl`(호스트 NVIDIA GL 스택) 마운트 패턴을 적용하면 tegra EGL 가속 — 후속 F008.

## ⚠️ 형제 디렉토리(청사진)는 DEPRECATED

`../wayland/`, `../qt-wayland/`, `../wayland-only/`, `../arm64-runtime/`, `../arm64-test/`, `../xwayland/`, `../rviz-source/`, `../Dockerfile.build.arm64` 는 **컨테이너 전환(ADR-014) 이전의 R005~R016 청사진**이다. 현재 정본은 본 `agl-display/` 다. (참고 보존용 — 삭제하지 않음.)

## 참고
- rviz2_agent 하네스: docs/design/F007-rviz2-pipeline-integration.md(파이프라인 통합), F006-switcher.md(스위처), ADR-014
- docs/rviz2/orin-agx-rviz2-on-agl-display.md (실기 실행 가이드)
