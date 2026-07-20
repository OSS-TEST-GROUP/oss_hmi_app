# Orin AGX — AGL IVI 디스플레이에 rviz2 띄우기 (컨테이너 방식)

> 대상: Jetson AGX Orin + AGL 20.0.3 (agl-ivi-demo-flutter 이미지)
> 검증: 2026-07-20 실기 통과 (인수 기준 5/5) — 실캡처로 확인
>
> **출처**: agl_image_agent repo `docs/guides/orin-agx-rviz2-on-agl-display.md` 의 사본.
> 본문에서 참조하는 설계 문서(ADR-0018)와 컨테이너 자산(`deploy/rviz2-container/`)은
> agl_image_agent repo 에 있다 — 이 사본의 상대 링크는 원본 repo 기준.

---

## 1. 개요 — 왜 컨테이너인가

rviz2(ROS 2 Humble)는 **Qt5 + X11 + OGRE(OpenGL/mesa)** 스택인데, AGL 이미지는
**wayland 전용(x11 없음) + Qt6 + NVIDIA GL** 이라 네이티브 탑재가 3중으로 충돌한다
(자세한 근거: ADR-0018 §1). 대신 **호스트 이미지는 한 줄도 바꾸지 않고**, 이미지에 이미
있는 docker 로 rviz2 스택 전체를 컨테이너에 격리한다.

```
IVI 디스플레이
 └─ agl-compositor (호스트 AGL — 불변)
     └─ cage (컨테이너, wlroots 키오스크 — agl-compositor 의 풀스크린 클라이언트)
         └─ XWayland (cage 내장)
             └─ rviz2 (Qt5/OGRE → llvmpipe SW-GL)   ← libOgreMain 은 rviz 패키지에 포함
                 └─ DDS (--net=host) ↔ 호스트 ros-core / Autoware 노드
```

핵심 포인트 2개 (실측으로 확정):
- **cage 를 쓰는 이유**: weston 9 는 xdg `set_app_id` 를 호출하지 않아 agl-compositor
  (agl-shell, app_id 기반 활성화)가 창을 표출할 수 없다. cage 는 `app_id="wlroots"` 를
  설정하므로 활성화 가능. 게다가 XWayland 내장 + 단일 앱 풀스크린이라 구조도 단순.
- **표출은 활성화가 필요**: AGL 은 `activate-by-default=false` 라 새 앱 창이 자동으로
  화면에 오지 않는다. `agl-shell-activator` 로 활성화한다 (스크립트가 자동 수행).

## 2. 전제 조건

| 항목 | 요구사항 | 확인 방법 (보드에서) |
|---|---|---|
| AGL 이미지 | agl-ivi-demo-flutter (docker + ros-core 포함) | `docker --version`, `ls /opt/ros` |
| 콤포지터 | agl-compositor 실행 중 | `ls /run/user/*/wayland-*` |
| 활성화 도구 | `agl-shell-activator` 존재 | `which agl-shell-activator` |
| 네트워크 | 컨테이너 빌드용 인터넷 (또는 이미지 파일 전송) | `ping 8.8.8.8` |
| 디스크 | 약 1.5GB 여유 (컨테이너 1.06GB) | `df -h /` |

보드 접속: `ssh root@<보드IP>` (이 문서 검증 보드: 172.16.10.162)

## 3. 자산 위치

agent repo `deploy/rviz2-container/`:

| 파일 | 역할 |
|---|---|
| `Dockerfile` | ros:humble-ros-base + rviz2 + cage/xwayland + llvmpipe, uid 1001 사용자 생성 |
| `entrypoint.sh` | 환경 검증 → `cage -- ros2 run rviz2 rviz2` |
| `run-on-board.sh` | 소켓 자동탐지 → docker run(소켓 소유자 uid) → **창 활성화 자동화** |

## 4. 절차

### 4-1. 자산 복사 + 컨테이너 빌드 (최초 1회, 약 5~10분)

```bash
# 개발 PC 에서
scp -r deploy/rviz2-container root@<보드IP>:/home/root/

# 보드에서
cd /home/root/rviz2-container
docker build -t rviz2-agl .
```

> 보드에 인터넷이 없으면 PC 에서 `docker buildx build --platform linux/arm64 -t rviz2-agl .`
> 후 `docker save rviz2-agl | ssh root@<보드IP> docker load`

### 4-2. 실행 (표출까지 자동)

```bash
# 보드에서
cd /home/root/rviz2-container
./run-on-board.sh
```

스크립트가 하는 일:
1. `/run/user/*/wayland-*` 에서 agl-compositor 소켓 자동 탐지
2. `docker run -d --net=host --ipc=host --user <소켓소유자uid>` 로 컨테이너 기동
   (cage 는 root 실행 거부 + 소켓 쓰기 권한 정합 — uid 매칭이 둘 다 해결)
3. `agl-shell-activator -a activate -p wlroots -o <output>` 반복 호출로 창 활성화

약 10~20초 후 IVI 디스플레이에 rviz2 가 풀스크린으로 표출된다.

### 4-3. 일상 조작

```bash
docker rm -f rviz2-agl-run                            # 중지 (홈스크린 복귀)
agl-shell-activator -a activate -p wlroots -o DP-1    # 홈스크린에 가려졌을 때 재표출
ROS_DOMAIN_ID=5 ./run-on-board.sh                     # DDS 도메인 변경
./run-on-board.sh -d /path/config.rviz                # rviz 설정 파일 지정 (컨테이너 내 경로)
```

> output 이름(DP-1 등)은 `agl-shell-activator -a getoutputs` 로 확인.
> 활성화 명령은 소켓 환경이 필요: `export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0`

## 5. 검증 방법

```bash
# ① 프로세스: cage / Xwayland / rviz2 세 개가 보여야 정상
docker exec rviz2-agl-run ps -eo user,cmd | grep -E 'cage|rviz|Xwayland'

# ② 화면 캡처 (원격 검증 — 실제 IVI 화면 그대로)
sudo -u agl-driver env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 agl-screenshooter
ls /tmp/agl-screenshot-*.png    # scp 로 가져와 확인

# ③ DDS: 호스트에서 rviz 노드가 보이면 양방향 발견 OK
source /opt/ros/humble/setup.bash && ros2 node list    # → /rviz 포함

# ④ libOgreMain 로드 확인
docker exec rviz2-agl-run bash -lc \
  'ldd /opt/ros/humble/lib/rviz2/rviz2 | grep libOgreMain'
# → libOgreMain.so.1.12.1 (rviz-ogre-vendor — 별도 OGRE 설치 불필요)
```

## 6. 트러블슈팅 (전부 실측에서 겪은 것)

| 증상 | 원인 | 해결 |
|---|---|---|
| `Failed to connect to parent Wayland compositor: Success` | `WAYLAND_SOCKET=` 를 **빈 값으로 set** — libwayland 가 fd 로 파싱해 stdin 연결 시도 | 절대 빈 값 set 금지, `unset WAYLAND_SOCKET` (entrypoint 반영됨) |
| 컨테이너는 돌지만 화면은 홈스크린 그대로 | 창 활성화 안 됨 (`activate-by-default=false`) | `agl-shell-activator -a activate -p wlroots -o <output>` |
| activator 가 `std::logic_error` 로 죽음 | `-o <output>` 누락 | `getoutputs` 로 output 확인 후 지정 |
| weston 으로 시도 시 활성화 불가 | weston 9 는 `set_app_id` 미호출 (WAYLAND_DEBUG 로 확인) | cage 사용 (본 가이드 구성) |
| `Unable to drop root ... refusing to start` (cage) | cage 는 root 실행 거부 | `--user <소켓소유자uid>` (run-on-board.sh 자동) |
| 소켓 connect 권한 오류 | 소켓은 agl-driver(1001) 소유, others 쓰기 불가 | 컨테이너를 uid 1001 로 실행 (위와 동일) |
| `failed to bind /tmp/.X11-unix/X0` (weston 경로) | 컨테이너에 X 소켓 디렉토리 없음 | cage 는 자체 처리 — weston 폴백 시 `mkdir -p /tmp/.X11-unix` |
| rviz2 창이 느림 | Phase 1 은 SW 렌더(llvmpipe) | 단순 씬 기준 ~30fps. 무거우면 Phase 2(tegra EGL 마운트) 검토 — ADR-0018 D-3 |

## 7. 한계와 다음 단계

- **렌더링**: 현재 소프트웨어(llvmpipe). Grid/TF/간단한 마커는 ~30fps 로 충분하지만
  대형 pointcloud 는 프레임 저하 예상 → Phase 2 (tegra EGL/GBM 컨테이너 마운트) 후보.
- **표출 정책**: 홈스크린 앱을 조작하면 rviz2 가 뒤로 갈 수 있음 — activator 재호출로 복귀.
  상시 데모라면 rviz2 를 AGL 앱(app_id 등록)으로 승격하는 방안 검토.
- **rviz 설정**: 보드에 Autoware 스택이 돌고 있어(`/api/*` 토픽) Fixed Frame·디스플레이
  구성을 담은 `.rviz` 파일을 만들어 Dockerfile 에 COPY 하면 부팅 즉시 실데이터 시각화 가능.

## 8. 참고

- 설계·대안 검토·실측 기록: [ADR-0018](../adr/0018-rviz2-on-agl-display-via-container.md)
- 관련: [ADR-0017 localllm 하네스](../adr/0017-localllm-harness-openwebui-pipe.md) (동일 보드/Tool Server 생태계)
- 파일: `deploy/rviz2-container/{Dockerfile,entrypoint.sh,run-on-board.sh}`
