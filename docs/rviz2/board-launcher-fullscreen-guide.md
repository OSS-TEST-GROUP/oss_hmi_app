# 보드에서 hmi_launcher 를 풀화면 메인화면으로 만들기 (AGL / Orin)

> 대상: AGL 20.0.3(trout) on Orin AGX. 보드 실측 기준 — `root@172.16.10.81`, 출력 `DP-1` 1920x1080.
> 관련: [board-display-orientation-guide.md](./board-display-orientation-guide.md) (가로/세로),
> [scenario-test-guide.md](./scenario-test-guide.md) (시나리오 테스트).

## 1. 증상

보드를 켜면 **AGL 기본 홈스크린과 hmi_launcher 가 겹쳐** 보인다. 런처는 출력의 왼쪽
일부(측정: 1080x1021)만 덮고, 나머지 영역·상단 패널에는 AGL 데모 홈스크린(Weather /
Clock / Navigation / Weston Terminal, 하단 Home·HVAC·Media·Settings·Apps)이 그대로 노출된다.

## 2. 원인 — 창 크기는 **클라이언트가 정할 수 없다**

agl-compositor 에서 서페이스 기하는 **agl-shell 이 소유**한다. 클라이언트가 요청하는
`xdg_toplevel.set_fullscreen` 은 무시되고, gRPC(`127.0.0.1:14005`)로만 바뀐다.

| 시도 | 결과 |
|---|---|
| `flutter-auto -f` (= `--fullscreen`) | 로그에 `Fullscreen: true` 만 찍히고 **화면은 그대로 겹침** |
| `flutter-auto -w 1920 -h 1080` | 위와 동일 (기본 요청 크기 `1920 x 720` 도 반영되지 않음) |
| gRPC `SetAppFullscreen` + `ActivateApp` | **전체 출력 차지 ✅** |

## 3. 지원 구성 — 런처 NORMAL 롤 + 자기 활성화

런처는 일반 앱(NORMAL)으로 뜨고, 기동 후 **스스로** 자기 서페이스를 풀화면·전면으로
올린다. AGL 기본 홈스크린은 **켜 둔 채** 뒤에 남지만 런처가 출력 전체(상단 패널까지)를
덮으므로 사용자에게는 hmi_launcher 가 메인화면이다.

| 파일 | 역할 |
|---|---|
| [apps/docker/script/agl-run.sh](../../apps/docker/script/agl-run.sh) | 기동 후 `SetAppFullscreen` + `ActivateApp` (백그라운드, 기본 15초 대기) |
| [apps/docker/dockerfile/Dockerfile.arm64](../../apps/docker/dockerfile/Dockerfile.arm64) | 정적 `grpcurl` 포함 (호스트 `agl-shell-activator` 는 libprotobuf/absl 링크라 마운트 불가) |
| [apps/rviz2_port/docker/agl-display/entrypoint.sh](../../apps/rviz2_port/docker/agl-display/entrypoint.sh) | cage(rviz2)에도 `SetAppFullscreen` (기본 켜짐, `AGL_SHELL_FULLSCREEN=0` 으로 끔) |

끄려면 `-e AGL_SHELL_ACTIVATE=0`, 출력이 다르면 `-e AGL_OUTPUT=<name>`,
대기를 늘리려면 `-e AGL_SHELL_ACTIVATE_DELAY=25`.

### 3-1. ⚠️ 호출 시점 — 너무 이르면 앱이 **영구 비표시**가 된다

서페이스가 매핑되기 전에 `SetAppFullscreen` 을 부르면 그 앱은 화면에서 사라지고, 이후
`activate` / `normal` / `fullscreen` 을 몇 번 불러도 **복구되지 않는다**(컨테이너 재생성만이
해결). 실측 경계:

| 기동 후 호출 시점 | 결과 |
|---|---|
| +2초 | 영구 비표시 ❌ |
| +5초 | 풀화면 ✅ |
| +15초 (기본값) | 풀화면 ✅ — 6/6 재현 |

agl-shell 은 ack 을 주지 않아 성공을 관측할 수 없고 `AppStatusState` 스트림도 applaunchd
등록 앱만 보고하므로(컨테이너 클라이언트는 이벤트 없음 — 실측) **대기 후 1회 호출**이 최선이다.

### 3-2. 레이어 규칙과 앱 전환

**풀화면 롤은 일반 창보다 위 레이어**다. 전체 화면을 쓰는 앱은 모두 풀화면 롤을 받아야
하고, 그 다음부터 `ActivateApp` 이 전환 스위치가 된다.

| 단계 | 호출 | 검증 |
|---|---|---|
| 런처 기동 | `SetAppFullscreen hmi_launcher` + `ActivateApp` (agl-run.sh) | 런처 풀화면 ✅ |
| rviz2 시작 | `SetAppFullscreen wlroots` + `ActivateApp wlroots` (entrypoint) | rviz2 풀화면 31fps ✅ |
| 홈 버튼(homebar) | `ActivateApp homebar` + `SetAppFloat` | 풀화면 rviz2 위에 유지 ✅ |
| 홈 복귀 | `DeactivateApp wlroots` + `ActivateApp hmi_launcher` (1초 뒤 1회 더) | 런처 복귀 ✅ |
| 홈 복귀 후 패널 조작 | — | **Stop 탭 정상** ✅ (입력 포커스가 런처로 넘어온다) |

`ActivateApp wlroots` **만** 부르면 rviz2 는 풀화면 런처 뒤에 숨는다 → "rviz2 가 안 뜬다".
`ActivateApp hmi_launcher` 는 **첫 호출이 무효인 경우가 있어**(실측) 1초 뒤 한 번 더 부른다
— [homebar.c](../../apps/rviz2_port/docker/agl-display/homebar.c),
[showHome()](../../apps/rviz2_panel/lib/controller/rviz2_controller.dart).

## 4. AGL 홈스크린을 제거할 수 있나 — **기술적으로 가능하지만 쓰지 않는다**

`flutter-auto --window-type BG` 로 런처를 **AGL 배경(BG) 롤**로 띄우면 출력 전체를 차지하고
홈스크린이 필요 없어진다(`systemctl disable --now flutter-ics-homescreen`). 동작까지
확인했다 — 런처 단독 전체화면, 타일 터치, rviz2 표출, 홈 버튼 복귀.

**그런데 제품 흐름에는 쓸 수 없다.** 실측된 제약 3가지:

| 제약 | 실측 내용 |
|---|---|
| **rviz2 실행 중 런처가 터치를 못 받는다** | 홈 복귀로 화면은 런처로 돌아오지만 입력 포커스가 cage 에 남아 타일·Stop·View rviz2 탭이 **전부 무반응**(앱은 살아 있음 — 로그 스트림만 갱신). 즉 패널로 rviz2 를 정지할 수 없다 |
| **agl_shell 셸 클라이언트 슬롯 점유** | BG 런처가 떠 있으면 홈스크린이 `agl_shell extension already in use by other shell client` 로 기동 실패. 되돌릴 때는 **런처 정지 → 컴포지터 재시작 → 홈스크린 기동** 순서를 지켜야 한다(경합하면 컴포지터가 죽는다 — 실측) |
| **잔류 서페이스** | 패널을 우회해 rviz2 를 만들고 지우면 컴포지터가 죽은 서페이스의 마지막 프레임을 계속 표시한다(컨테이너 0개인데 화면은 rviz2). 런처 컨테이너 재생성으로 복구 |

또한 `--window-type BG` **없이** 홈스크린만 정지하면 화면이 완전히 검어지고 새 런처
컨테이너도 표출되지 않는다(홈스크린이 배경/셸 클라이언트 역할을 하고 있어서).

**결론**: 홈스크린은 **켜 둔다**. 런처 풀화면이 그 위를 100% 덮으므로 화면상으로는 제거된
것과 같고, 입력·복구 경로가 모두 정상이다. BG 는 "rviz2 를 쓰지 않는 키오스크" 같은
용도에서만 선택지다(그 경우 `AGL_SHELL_FULLSCREEN=0` 으로 cage 풀화면 롤을 끈다).

## 5. 문제 해결

| 증상 | 조치 |
|---|---|
| 런처가 아예 안 보인다 | 서페이스가 poisoned 됨 → `docker stop hmi_launcher && docker rm hmi_launcher && docker restart oss-mmf-ext-agl` |
| 런처가 부분창으로 겹쳐 보인다 | 자기 활성화가 실행되지 않음 → `docker logs hmi_launcher \| grep agl-shell` 확인 (grpcurl 없는 구버전 이미지인지) |
| rviz2 를 켰는데 화면이 런처 그대로 | cage 가 풀화면 롤을 못 받았다 → 이미지 갱신, 또는 임시로 `agl-shell-activator -a fullscreen -p wlroots` |
| 홈 버튼을 눌러도 rviz2 가 그대로 | 구버전 이미지(홈 복귀가 `ActivateApp` 1회만) → 이미지 갱신, 또는 `agl-shell-activator -a activate -p hmi_launcher -o DP-1` 2회 |
| 화면이 rviz2 인데 컨테이너가 없다 | 잔류 서페이스 → 런처 컨테이너 재생성 |
| 부팅 후 검은 화면 | `docker.service` 가 소켓 활성화만 돼 있으면 컨테이너가 안 뜬다 → `systemctl enable docker` (실측: 부팅 37분 뒤 첫 docker 명령에서야 기동) |
| 컴포지터/홈스크린을 재시작했다 | 기존 서페이스가 모두 끊긴다 → 런처·rviz2 컨테이너를 재생성해야 다시 보인다 |

수동 점검(호스트):

```bash
agl-shell-activator -a getoutputs                       # DP-1
agl-shell-activator -a fullscreen -p hmi_launcher
agl-shell-activator -a activate   -p hmi_launcher -o DP-1
su -s /bin/sh agl-driver -c 'cd /tmp && XDG_RUNTIME_DIR=/run/user/1001 \
  WAYLAND_DISPLAY=wayland-0 weston-screenshooter'       # /tmp/wayland-screenshot-*.png
```

## 6. 배포 상태 (2026-08-07)

보드 `172.16.10.81` 구성 — 전 과정 터치로 검증(타일 → Start → 홈 버튼 → Stop):

| 항목 | 값 |
|---|---|
| hmi_launcher | `oss-hmi-launcher:develop-20260807-8229899-arm64` (NORMAL 롤 + 자기활성화) |
| rviz2 | `rviz2-agl:latest` = `autoware-develop-20260807-4201d2d` (멀티아치) |
| ext-agl | `oss-mmf-ext-agl:develop-20260806-169f697` (MMF develop HEAD 빌드) |
| AGL 홈스크린 | **enabled/active** (배경·셸 클라이언트로 필요 — 4절) |
| docker | `docker.service` enabled (부팅 자동시작) |

레지스트리 발행 완료:

```
rviz2-agl:latest, :autoware-develop-20260807-4201d2d   (+ per-arch amd64/arm64)
oss-hmi-launcher:develop-20260807-8229899-arm64        (:latest 없음 — 배포 규약)
```

per-arch 네이티브 빌드(QEMU 회피) → per-arch push → 매니페스트 결합:

```bash
REG=registry.obigo.com/oss
RVER=autoware-develop-20260807-4201d2d
docker push "$REG/rviz2-agl:$RVER-amd64"                           # 개발 PC
ssh beyhpc@172.16.10.151 "docker push $REG/rviz2-agl:$RVER-arm64"   # 151(aarch64)
docker buildx imagetools create -t "$REG/rviz2-agl:$RVER" \
    "$REG/rviz2-agl:$RVER-amd64" "$REG/rviz2-agl:$RVER-arm64"
docker buildx imagetools create -t "$REG/rviz2-agl:latest" \
    "$REG/rviz2-agl:$RVER-amd64" "$REG/rviz2-agl:$RVER-arm64"
```
