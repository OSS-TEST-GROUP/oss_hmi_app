# Settings (System setup) 사용 가이드

> 대상: 운영자. hmi_launcher 홈의 **"Settings / System setup"** 카드로 진입하는 런처 내장
> 설정 화면 + 상단바의 **Manage Apps** 사용법. (런처 전반 구조는 런처 셸 문서 참조)

## 1. 개요

Settings 는 HMI 를 차량 백엔드에 연결하고 외관/현지화를 조정하는 **런처 내장 제어판**입니다. 한 화면에서:
- **rosbridge 연결**(브리지 IP + 포트)
- **DDS / ROS Domain 설정**(두 평면 분리, 로컬 저장, 컨테이너 재시작, 원격 호스트 전파)
- **임베드 모니터 4앱(OTA/ADSW/Diagnostic/Lifecycle)의 라이트/다크 테마**
- **Service Mode**(NORMAL / OTA_MODE 일괄 적용)
- **표시 시간대(time zone)**
를 설정하고, **런타임 상태**(AI SDK / ROS bridge / 입력기)를 읽기전용으로 확인합니다. 별도의 **Manage Apps**(상단바) 화면에서 발견된 앱을 홈/사이드바에 표시/숨김 할 수 있습니다.

**진입**: 홈의 "Settings / System setup" 카드 탭. **닫기**: 상단바 X 버튼.

## 2. Connection (연결)

| 항목 | 설명 |
|---|---|
| **Bridge IP address** | rosbridge WebSocket 의 호스트 |
| **Port** | 포트 (기본 9090) |
| **Vehicle profile** | ⚠️ **표시용(cosmetic)** — 입력해도 저장/사용되지 않음 |
| **Apply** | 검증(호스트 비어있지 않음, 포트 1–65535) 후 `ws://<ip>:<port>` 로 연결 |

- **저장**: `config.json` 의 `rosbridge.url`. 위치: `$HMI_LAUNCHER_CONFIG` → `$XDG_CONFIG_HOME/hmi_launcher/config.json` → `~/.config/hmi_launcher/config.json` → `/var/lib/hmi_launcher/config.json`.
- **반영**: **즉시** — 기존 ROS 연결을 끊고 새 URL 로 재연결("Reconnecting"→"Configured"). 앱 재시작 불필요.
- 잘못된 입력: "Enter a valid bridge IP and port." (빨강).

## 3. DDS / ROS Domain (도메인 평면 설정)

MMF 의 두 통신 평면(DDS 버스 vs ROS2/rmw 그래프)의 도메인을 설정합니다:

| 항목 | 기본값 | 설명 |
|---|---|---|
| **DDS domain** | `42` | 순수 Fast-DDS 버스 (`ota_mgr`, `lifecycle_mgr`, `adsw_manager`, `diagnostics`, `vehicle_info_mgr`) |
| **ROS domain** | `42` | ROS2/rmw 그래프 (`rviz2`, `Autoware`, `rosbridge_server`) |
| **Save domains** | — | 유효 범위(0~232) 검증 후 로컬 도메인 파일 기록 + 컨테이너 재시작/원격 전파 |

- **두 도메인 분리 경고**: DDS domain 과 ROS domain 이 다르면 화면에 경고(⚠️)가 표시됩니다. 두 평면 간 통신은 `dds_bridge` 를 경유해서만 전달됩니다.
- **저장 위치**: `/opt/mmf/config/domain.env` (또는 환경변수 지정 경로).
- **적용 및 원격 전파**:
  1. 도메인은 프로세스 시작 시점에 읽히므로, 설정 저장 후 **MMF 컨테이너 재시작 또는 재생성**이 필요합니다(`docker restart` 로 불충분한 경우 재생성 알림 표시).
  2. 원격 호스트(차량 컴퓨트 등)가 분리되어 있는 경우, rosbridge 를 통해 원격의 `domain_agent` 에 도메인 갱신 요청을 전달하고 반영 확인(`acked` / `unconfirmed` / `failed`) 상태를 스낵바로 피드백합니다.

## 4. App Theme (앱 테마)

임베드 모니터별 라이트/다크 토글 4개:
- **OTA Monitor**, **ADSW Monitor**, **Diagnostic Monitor**, **Lifecycle Monitor**

- **변경 대상**: 해당 모니터 앱의 팔레트만(런처 셸 자체 테마 아님).
- **저장**: `config.json` 의 `otaTheme` / `adswTheme` / `diagTheme` / `lfcTheme`.
- **반영**: **즉시**(각 앱 팔레트에 라이브 반영). 현재값 버튼은 하이라이트/비활성.

## 5. Service Mode (전체 서비스 모드 제어)

모든 등록된 Lifecycle 서비스에 대해 동작 모드를 일괄 적용합니다:
- **NORMAL**: 통상 주행/서비스 동작 모드 (기본값 `0`)
- **OTA_MODE**: OTA 업데이트 전용 모드 (`1`)
- **Apply**: 라이브 `LifecycleCollector` 를 통해 전 서비스 일괄 모드 변경 요청 전송.

## 6. Localization (현지화)

- **Time zone** 드롭다운: Korea KST(UTC+9, 기본), Japan JST, China CST, India IST, Central Europe CET, UTC, US Eastern EST, US Pacific PST.
- **변경 대상**: 홈의 시계·인사말(Good morning/afternoon/evening)·채팅 타임스탬프. 호스트 시간대와 무관하게 `UTC+offset` 로 계산.
- **저장**: `timezone.json`(`hmi_launcher` config 디렉토리). 고정 표준시(DST/IANA 미적용). **반영 즉시**.

## 7. Runtime (읽기 전용 상태)

- **AI SDK**: Enabled/Disabled — 기동 시 v_agentos 데몬(기본 `localhost:50051`) 연결 가능 여부 반영.
- **ROS bridge**: Configured / Reconnecting / Disabled.
- **Input method**: "Shared"(고정).

> 여기서는 **상태 표시만** 합니다(편집 불가).

## 8. Manage Apps (앱 표시/숨김)

**진입**: 상단바 **Manage Apps** 버튼(툴팁 "Manage Apps").

- 발견된 **모든 앱**을 목록으로 표시(아이콘·이름·`category · v버전`), 우측 **스위치**로 표시/숨김.
- 스위치 토글 = **즉시** 반영·저장(홈 그리드 + 사이드바 레일에 바로 반영). 숨긴 앱 이름은 회색.
- 현재 열려있는 앱을 숨기면 홈으로 이동.

### OTA Monitor 기본 숨김
- 신규 설치(상태파일 없음) 시 `kDefaultDisabled = {'ota_monitor'}` 로 **OTA Monitor 만 기본 숨김**, 나머지는 기본 표시.
- 사용자가 Manage Apps 에서 **OTA Monitor 를 켜면** 이후 재시작에도 유지(상태파일이 기본값을 대체).
- **저장**: 숨김 집합만 `app_visibility.json`(`{"disabled":[...]}`, `hmi_launcher` config 디렉토리). 파일 손상 시 기본 숨김 집합으로 폴백(OTA 재등장 방지).

## 9. Settings 에 없는 것 (위치 안내)

- **AI SDK / launcher-bot 토글**(Standard ↔ AI SDK): **상단바**에 있음(데몬 사용 가능 시에만 표시). Settings 는 상태만 보고.
- **reconnect / heartbeat 간격**(`rosReconnectIntervalSec` 기본 2s, `heartbeatIntervalSec` 기본 1s): UI 편집 불가 — `config.json` 직접 수정.

## 10. 기타 상단바 조작

- **Restart Launcher**(툴팁 "Restart launcher"): 확인 다이얼로그("런처를 종료하시겠습니까?") → OK 시 `exit(0)`. config 변경이 완전 재시작을 요할 때 사용.

## 11. 조작 요약

- Settings 열기: 홈 "Settings" 카드 탭 / 닫기: 상단바 X.
- 텍스트 필드(IP/Port/Vehicle profile): 화면 키보드 → **Apply** 로 연결 반영.
- 도메인 설정: DDS / ROS domain 숫자 입력 → **Save domains** (로컬 반영 + 원격 전파).
- 서비스 모드: NORMAL / OTA_MODE 선택 → **Apply**.
- 테마·시간대: 탭/선택 시 즉시 반영.
- Manage Apps: 상단바 버튼 → 스위치 토글(즉시) → Back 으로 복귀.
