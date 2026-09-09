# rviz2_panel — RViz2 Panel

rviz2 컨테이너의 **기동/정지 · 화면 배치 · 실행 옵션 편집 · 로그 표시**를 제공하는 HMI.
런처 카드 "RViz2 Panel"(🤖)로 진입하며, hmi_launcher 에 임베드되거나 단독 실행된다.

## 개요 — direct-docker 변형

예전 v1 은 rosbridge 로 `ctrl/StartContainer` 를 발행해 lifecycle_mgr → adsw_manager 를
거쳐 컨테이너를 제어했다. 현재는 **패널이 직접 `docker` 를 호출**한다 (rosbridge·roslibdart
의존성 제거 — `lib/ros_keeper.dart` 는 삭제 표식만 남아 있다).

| 기능 | 구현 |
|---|---|
| 기동 / 정지 | `docker run -d --name rviz2 …` / `docker stop` (컨트롤러가 CLI 실행) |
| 상태 | `docker inspect` 를 `pollIntervalSec` 주기로 폴링 → RUNNING/STOPPED/exit_code |
| 로그 | `docker logs --tail 300` + `docker logs -f` 스트림 → 링 버퍼 |
| 화면 배치 | agl-shell gRPC(`127.0.0.1:14005`) — `SetAppNormal → SetAppFloat → SetAppScale → ActivateApp` |
| 홈 복귀 | rviz2 컨테이너 안의 homebar(홈 버튼)가 `SetAppNormal + DeactivateApp` 수행 |

> **동작 전제**: 런처 컨테이너 안에서 `docker` CLI 가 데몬에 닿아야 한다 —
> `/var/run/docker.sock` 마운트 + docker gid(`--group-add`). 보드(arm64)는 adsw 서비스
> 정의가, x86 은 `docker/script/run-hmi-x86.sh` 가 자동으로 준다.

## 배경

rviz2 렌더링(cage surface)은 Flutter 에 임베드할 수 없다(ADR-014). 그래서 **제어판만
임베드**하고, rviz2 는 별도 wayland 클라이언트로 띄운 뒤 **런처 안 패널이 차지한 사각형에
맞춰 배치**한다. adsw_manager 레지스트리에는 `recovery_policy=MANUAL +
init_state=NOT_RUNNING` 으로 등록되어 자동 기동/복구를 하지 않고, 기동은 이 패널이 트리거한다.

## 화면 구성

가로 화면에서 **좌 : 우 = 3 : 1** 로 나뉜다. 가운데 핸들을 끌어 비율을 조절하고,
더블탭하면 기본값(3:1)으로 돌아간다.

- **좌** — `RViz2 Control`(상태·Start/Stop/View rviz2) → `패널 설정`(영구 저장) → `Run Options`
- **우** — `docker logs` (전체 높이)

## 설정

두 파일 모두 **쓰기 가능한 `$XDG_CONFIG_HOME` 안**에 둔다. 보드에서는
`XDG_CONFIG_HOME=/cfg` 가 호스트 `/root/oss/hmi_launcher_cfg` 로 마운트돼 있어 재기동 후에도 남는다.

| 파일 | 뜻 | 만드는 주체 |
|---|---|---|
| `config_def.json` | **기기 기본값** | 패널이 첫 실행에 생성 (이미 있으면 덮지 않는다) |
| `config.json` | **사용자 변경분** | 화면의 "저장" 버튼 |

탐색 순서: `config.json` → `config_def.json` → `--config <path>` → env `RVIZ2_MONITOR_CONFIG`
→ `./config/config.json` → 코드 기본값(`AppConfig.defaults`, 그리고 그 값으로 `config_def.json` 생성).
"기본값으로" 버튼은 `config.json` 을 `.bak` 으로 치워 기기 기본값으로 되돌린다.

> 리포의 `config/config.json` 은 **단독 실행일 때만** 읽힌다(cwd 가 앱 디렉토리). 임베디드
> 패널은 런처 프로세스의 cwd 가 `/` 라서 그 파일에 닿지 않는다 — 보드에서 값을 바꿀 때는
> 화면에서 저장하거나 `config_def.json` 을 고친다. Yocto 이미지에 넣을 파일은 없다.

### 필드

| 키 | 뜻 | 기본값 |
|---|---|---|
| `image` | 기동할 rviz2 이미지 | `registry.obigo.com/oss/rviz2-agl:latest` |
| `containerName` | `docker run --name` / stop / logs 대상 | `rviz2` |
| `aglOutput` | 표출 화면(agl-shell output) | `DP-1` |
| `rvizAppId` | rviz2 창의 app_id (cage 가 만드는 이름) | `wlroots` |
| `homeAppId` | 홈 복귀 시 활성화할 런처 app_id | `hmi_launcher` |
| `pollIntervalSec` | 상태 폴링 주기(초) | `3` |
| `dockerRunArgs` | `docker run` 에 넘길 인자 목록 | cage/wayland 세트 |
| `defaultDomainId` | `ROS_DOMAIN_ID` 프리필 | 런처 Settings 값, 없으면 `42` |
| `rvizConfigPath` | `RVIZ_CONFIG` (entrypoint 가 `rviz2 -d`) | 빈 값 |
| `rmwImplementation` | `RMW_IMPLEMENTATION` | 빈 값 |

`dockerRunArgs` 는 화면에서 **인자 하나가 한 줄**로 보인다(값이 있으면 같은 줄):

```
--net=host
--user 1001:1001
-e XDG_RUNTIME_DIR=/host-xdg
```

파일에는 docker 가 받는 그대로 토큰 하나씩 저장된다(`"--user", "1001:1001"`).

### Run Options — 이번 기동에만 쓰이는 값

`ROS_DOMAIN_ID` / `RMW_IMPLEMENTATION` / `RVIZ_CONFIG` 를 `-e` 로 덧붙인다.
"Autoware (151) preset" 버튼이 세 값을 한 번에 채운다(도메인 42 · FastDDS · `autoware.rviz`).
**저장하지 않으면 다음 기동에 초기화**된다 — 계속 쓰려면 패널 설정에서 저장한다.
도메인은 저장하지 않는 한 런처 Settings 의 "DDS domain" 을 따른다.

## 보드(arm64) vs x86

컨테이너 이미지는 같고, **entrypoint 가 표시 경로를 보고 모드를 고른다** — wayland 소켓이
있으면 cage, 없고 `DISPLAY` 만 있으면 x11 직행.

| 기능 | 보드(AGL) | x86 |
|---|---|---|
| Start / Stop / 상태 / 로그 | ✅ | ✅ (docker 소켓 필요) |
| rviz2 표출 | cage + 패널 영역 배치 | 독립 X 윈도우 (WM 이 배치) |
| `View rviz2` / 홈버튼 | ✅ | ❌ — agl-compositor 가 없어 agl-shell 호출이 무효 |

x86 에서는 `dockerRunArgs` 를 X11 세트(`-e DISPLAY`, `/tmp/.X11-unix` …)로 바꿔야 한다.
절차는 `apps/docker/docs/DOCKER_GUIDE.md` §1-5 참조.

## 빌드 · 테스트

```bash
# 단독 빌드 (개발용)
flutter build linux --release

# 단위 테스트 — 빌더 이미지(Flutter 3.32.5)에서 돌린다
cd apps && docker run --rm -v "$PWD":/workspace/apps --user $(id -u):$(id -g) \
  -e HOME=/tmp -e PUB_CACHE=/tmp/.pub-cache --entrypoint bash \
  registry.obigo.com/oss/oss-hmi-builder:x86-flutter3.32.5 \
  -c 'cd /workspace/apps/rviz2_panel && flutter pub get && flutter test'
```

> 이 패널은 hmi_launcher 의 path 의존성이라, 런처 이미지를 다시 만들면 함께 반영된다
> (`apps/docker/docs/DOCKER_GUIDE.md` §1-2 → §6).

## 관련

- `apps/rviz2_port/docker/agl-display/README.md` — rviz2 컨테이너(cage·homebar·오버레이) 정본
- `apps/docker/docs/DOCKER_GUIDE.md` — 빌드·레지스트리 push·x86 실행
- ADR-014: RViz2 렌더링 임베드 불가 판정
- F010 설계 문서: `rviz2_agent/docs/design/F010-rviz2-monitor.md`
- lfc_monitor: 동일 패턴의 lifecycle 모니터 (템플릿)
