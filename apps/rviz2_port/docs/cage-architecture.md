# cage — rviz2 를 AGL 순수 Wayland 에 띄우는 중첩 컴포지터

> `entrypoint.sh` 마지막 줄 `exec cage -- ros2 run rviz2 rviz2` 의 cage 가 무엇이고,
> 왜 이 구조여야 하는지 정리한 문서. 흩어져 있던 근거(각 Dockerfile·entrypoint 주석,
> `docs/rviz2/orin-agx-rviz2-on-agl-display.md`)를 한곳에 모았다.
>
> 대상 구성: Orin AGX + AGL 순수 Wayland, `apps/rviz2_port/docker/agl-display/` 이미지.

---

## 1. cage 란 무엇인가

[cage-kiosk/cage](https://github.com/cage-kiosk/cage) — **wlroots 기반의 최소 키오스크
Wayland 컴포지터**. `cage -- <프로그램>` 으로 넘긴 **앱 하나만 화면 전체에** 띄우는 것이
기능의 전부다.

없는 것: 창 장식(타이틀바·테두리), 창 이동·리사이즈, 다중 창 관리, 패널·런처·데스크톱 크롬.
있는 것: 풀스크린 서페이스 1장, 입력 전달, (빌드 옵션에 따라) XWayland 내장.

키오스크·디지털 사이니지·임베디드 HMI 처럼 "앱 하나가 화면을 독점하는" 용도로 쓰인다 —
rviz2 를 IVI 디스플레이에 띄우는 이 프로젝트의 요구와 정확히 일치한다.

## 2. 이 스택에서 cage 의 위치 — 중첩(nested) 컴포지터

```
IVI 디스플레이
 └─ agl-compositor              (호스트 AGL — 이미지 불변)
     └─ cage                    (컨테이너: 호스트의 wayland 클라이언트, app_id="wlroots", 풀스크린 1장)
         └─ XWayland            (cage 내장)
             └─ rviz2           (Qt5 + X11 + OGRE 1.12.1 → llvmpipe SW-GL)
                 └─ DDS (--net=host) ↔ 호스트/원격 ROS2 · Autoware 노드
```

cage 는 **두 얼굴**을 가진다:

- **밖으로는 클라이언트** — 호스트 `agl-compositor` 에 붙는 평범한 Wayland 앱(창 하나).
  그래서 호스트 이미지를 한 줄도 고치지 않고 컨테이너만으로 rviz2 를 올릴 수 있다.
- **안으로는 컴포지터** — rviz2 입장에서 cage 가 디스플레이 서버다. `-Dxwayland=true` 로
  빌드돼 XWayland 를 내장하므로, **Wayland 네이티브가 아닌 rviz2(Qt5 X11 QPA)를 x11 없는
  AGL 에서 그대로 실행**할 수 있다.

즉 cage 는 **"X11 을 요구하는 앱"과 "Wayland 전용 호스트" 사이의 어댑터**다. 이것이 cage 가
이 스택에 존재하는 핵심 이유다.

## 3. 왜 cage 인가 (weston 대신) — 실측 근거

| 이유 | 내용 |
|---|---|
| **app_id 를 설정한다** | AGL 의 `agl-shell` 은 **app_id 기반**으로 창을 활성화한다. weston 9 는 xdg_toplevel `set_app_id` 를 호출하지 않아(WAYLAND_DEBUG 로 확인) agl-compositor 가 그 창을 활성화·표출할 수 없었다. cage 는 `app_id="wlroots"` 를 설정 → `agl-shell-activator -a activate -p wlroots` 가 동작한다 |
| **단일 앱 풀스크린** | rviz2 하나만 띄우면 되는 요구에 정확히 부합. 데스크톱 크롬·창 관리 로직이 없어 구조가 단순 |
| **XWayland 내장** | 별도 Xwayland 기동·소켓 관리 스크립트가 불필요 (weston 폴백 시엔 `/tmp/.X11-unix` 를 직접 만들어야 했다) |

## 4. `exec cage -- …` 의 의미 — 프로세스와 생명주기

[../docker/agl-display/entrypoint.sh](../docker/agl-display/entrypoint.sh) 마지막 줄:

```bash
exec cage -- ros2 run rviz2 rviz2 "${rviz_args[@]}" "$@"
```

- `exec` → cage 가 **컨테이너의 PID 1** 이 된다.
- cage 가 rviz2 를 **자식으로** 띄운다 → `rviz2 종료 = cage 종료 = 컨테이너 종료`.
  생명주기가 하나로 묶여 유령 프로세스가 남지 않는다.
- 정상 상태의 프로세스 3종: `cage` / `Xwayland` / `rviz2`.

```bash
docker exec rviz2-agl-run ps -eo user,cmd | grep -E 'cage|Xwayland|rviz'
```

> **homebar 는 cage 트리 밖**이다. 홈 버튼은 cage 와 무관하게 **호스트 agl-compositor 의
> 일반 Wayland 클라이언트**로 뜬다 — 같은 컨테이너에서 돌리는 것은 이미지·생명주기 통합
> 목적일 뿐이다 (`Dockerfile.touch` 주석 참조).

## 5. 소켓이 두 개다 — 헷갈리기 쉬운 지점

| 소켓 | 만드는 주체 | 용도 |
|---|---|---|
| `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` (예: `/host-xdg/wayland-0`) | 호스트 agl-compositor | cage 가 **클라이언트로 접속**. `run-on-board.sh` 가 `/run/user/<uid>` 를 마운트해 넘긴다 |
| `$XDG_RUNTIME_DIR/wayland-N` (N ≠ 위 이름) | **cage 자신** | rviz2/XWayland 가 붙는 중첩 컴포지터 소켓 |

entrypoint 의 homebar 시퀀스는 이 **cage 자체 소켓의 등장을 "cage 가 떴다"는 신호**로 쓴다
(호스트 소켓과 `*.lock` 을 제외한 `wayland-*` 탐색). agl-shell 은 ack 을 주지 않아 가시성을
관측할 수 없기 때문에, 관측 가능한 파일 사건에 순서를 앵커한 것이다.

관련 실측 함정: **`WAYLAND_SOCKET` 을 빈 값으로라도 export 하면 안 된다** — libwayland 가 이를
fd 로 파싱해 stdin 에 접속을 시도하고 `Failed to connect to parent Wayland compositor: Success`
로 죽는다. entrypoint 는 `unset WAYLAND_SOCKET` 으로 처리한다.

## 6. 표출은 별도 단계 — 기동 ≠ 화면 표시

AGL 은 `activate-by-default=false` 이므로 cage 창이 떠도 자동으로 화면에 오지 않는다.

```bash
# 호스트에서 (소켓 환경 필요)
export XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0
agl-shell-activator -a getoutputs                      # output 이름 확인 (DP-1 등)
agl-shell-activator -a activate -p wlroots -o DP-1     # app_id=wlroots(=cage) 활성화
```

- `run-on-board.sh` 는 이 activate 를 반복 호출해 자동화한다.
- 컨테이너 안에서는 grpc 경로도 쓴다 — entrypoint 의 homebar 블록이
  `AglShellManagerService/ActivateApp {"app_id":"wlroots"}` 를 호출한 뒤 homebar 를 그 위에 float.
- **ext-agl(adsw_manager) 자동기동은 `docker run` 만 하고 활성화는 안 한다** → 표출은 F006
  스위처(상시기동 + activate-swap) 담당.

## 7. cage 실측 제약과 대응 (전부 실기에서 겪은 것)

| 제약 | 원인 | 대응 |
|---|---|---|
| **root 로 실행 거부** (`Unable to drop root … refusing to start`) | cage 의 정책 | `docker run --user 1001:1001` (호스트 agl-driver uid). 소켓 쓰기 권한 정합도 동시에 해결 — `run-on-board.sh` 가 소켓 소유자 uid 를 자동 사용 |
| **터치가 rviz2 에 안 온다** (포인터·키보드만) | jammy apt 패키지 cage 0.1.4 + wlroots 0.15.1 은 **중첩 wayland 백엔드에서 터치 전달 미구현** | wlroots 0.16+ 계열을 **소스 빌드** (`Dockerfile.touch`). 아래 §8 |
| **`docker stop` 이 느리다 / exit 133 abort** | wayland 1.21+ 의 `wl_display_terminate` 가 종료용 eventfd write 결과를 assert → SIGTERM 경로에서 실패해 abort. SIGTERM 자체도 안 먹혀 hang→SIGKILL | wayland 를 `-Db_ndebug=true` 로 빌드(assert 만 제거, write 는 수행) + 이미지에 `STOPSIGNAL SIGKILL` |
| 컨테이너는 도는데 홈스크린 그대로 | 활성화 안 됨 (§6) | `agl-shell-activator -a activate -p wlroots -o <output>` |
| activator 가 `std::logic_error` 로 죽음 | `-o <output>` 누락 | `getoutputs` 로 확인 후 지정 |
| rviz2 가 느리다 (~30fps) | 현재 llvmpipe **SW 렌더** (`LIBGL_ALWAYS_SOFTWARE=1`) | 단순 씬은 충분. 대형 pointcloud 는 tegra EGL 가속(F008, `/opt/nv-gl` 마운트 패턴) 후보 |

## 8. 터치용 소스 빌드 스택 (`Dockerfile.touch`)

apt 패키지로는 터치가 안 되므로, `:base` 이미지 위에 아래를 순서대로 소스 빌드한다.
cage 는 이 버전에서도 `app_id="wlroots"` 를 계속 설정하므로 **agl-shell 활성화 정합은 유지**된다.

| # | 구성요소 | 버전 | 이유 |
|---|---|---|---|
| 1 | wayland | 1.22.0 | jammy 는 1.20, wlroots 0.16 은 ≥1.21 요구. `-Db_ndebug=true` (§7 exit 133) |
| 2 | wayland-protocols | 1.31 | wlroots 0.16 요구분 + xdg-shell.xml(homebar 빌드용) |
| 3 | libseat (seatd) | 0.8.0 | wlroots 0.16 이 libseat 를 무조건 링크(옵션 제거 불가). 런타임엔 중첩 백엔드가 session 을 안 써 링크만 되면 됨 |
| 4 | wlroots | 0.16.2 | **wayland 백엔드 터치 전달 포함**. `-Dxwayland=enabled` |
| 5 | cage | v0.1.5 | wlroots 0.16 호환 + `-Dxwayland=true` |

빌드 후 `ldconfig` 로 `/usr/local` 을 우선하게 하고 **apt cage 는 제거**(`dpkg -r`)해 경로 충돌을 막는다.
네이티브 arm64(보드/arm64 호스트) 빌드 권장 — QEMU 는 매우 느리다.

태그 규약: **`:base` → `:touch` → `:autoware`(= `:latest`)**.

## 9. cage 를 쓰지 않는 경로

x86 개발/CI 에서는 cage 를 우회한다 — 호스트에 X11 이 이미 있으므로 어댑터가 불필요하다.

```bash
bash apps/docker/script/run-rviz2-x86.sh    # 호스트 X11 에 rviz2 직접 실행. GPU=nvidia|none
```

즉 **cage 는 "AGL 순수 Wayland 보드" 전용 장치**이고, 데스크톱 리눅스에서는 존재 이유가 없다.

## 10. 참고

- 컨테이너 운영 가이드: [../docker/agl-display/README.md](../docker/agl-display/README.md)
- 보드 실기 절차·검증·트러블슈팅: [../../../docs/rviz2/orin-agx-rviz2-on-agl-display.md](../../../docs/rviz2/orin-agx-rviz2-on-agl-display.md)
  (agl_image_agent repo 사본 — 2026-07-20 기준이라 터치 소스빌드 이전 내용)
- 소스: [../docker/agl-display/entrypoint.sh](../docker/agl-display/entrypoint.sh) ·
  [Dockerfile](../docker/agl-display/Dockerfile) ·
  [Dockerfile.touch](../docker/agl-display/Dockerfile.touch) ·
  [run-on-board.sh](../docker/agl-display/run-on-board.sh)
- 설계 근거 원본 ADR-0018 은 **agl_image_agent repo** 에 있다 (이 repo 미포함)
