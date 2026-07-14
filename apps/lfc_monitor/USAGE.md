# Lifecycle Monitor 사용 가이드

> 대상: 운영자 (앱 사용법). 런처(hmi_launcher) 안에서 **"Lifecycle Monitor"**(🔄) 카드로
> 실행되거나 단독 앱으로 실행됩니다.

## 1. 개요

Lifecycle Monitor 는 **차량 소프트웨어 서비스와 호스트 컨테이너의 상태를 실시간으로 보고,
직접 제어하는 HMI 대시보드**입니다. MMF `lifecycle_mgr`/`adsw_manager` 백엔드에 rosbridge 로
접속해:
- 어떤 컨테이너가 있고 실행 중인지, 그 안의 서비스가 어떤 lifecycle 상태(RUNNING/NOT_RUNNING 등)인지
- 비정상 종료 코드(exit code)
- 상태 전이·명령 응답의 실시간 타임라인
을 보여주고, **컨테이너/서비스 시작·정지, 복구 정책 변경, 전체 OTA 모드 전환**을 수행합니다.

## 2. 화면 구성

단일 화면. 상단 앱바 + 두 패널(넓은 화면은 좌우, 좁으면 상하).

### 앱바
- 제목 `lfc_monitor`
- **연결 표시**: `● connected`(초록) / `○ disconnected`(회색)
- 현재 **rosbridge URL** (회색 소자)
- **Settings**(톱니) 버튼 → 설정 다이얼로그

### 패널 A — "Containers & Services" (좌/상)
카드 스크롤 목록:
- **컨테이너 카드**(이름순): 상태 dot + 이름 + (exit 칩) + **상태 badge**(RUNNING/STOPPED/PAUSED/UNKNOWN), 이미지 문자열, **Start/Stop 버튼**(not RUNNING 이면 Start, RUNNING 이면 Stop 활성), 그 아래 소속 **서비스 행**들.
- **서비스 행**: 상태 dot + 이름 + (exit 칩) + 상태 badge(NOT_RUNNING/INITIALIZING/RUNNING/RUNNING_NO_RESPONSE/TERMINATING/UNKNOWN) + **Start/Stop** + **Recovery policy 드롭다운**(우측).
- **"Services (no container)"** 카드: 컨테이너 없는 서비스(예: AGL 앱) 모음.
- 비어있으면: "no containers/services yet — waiting for NotifyContainerState / LifecycleDiagReport…".

### 패널 B — "Events" (우/하)
상태 전이 + 명령 응답의 **최신순** 타임라인(최대 100). 각 행 = `HH:MM:SS.mmm` + dot + 텍스트:
- 서비스 상태 변화: `<service>: <FROM> → <TO>`
- 컨테이너 상태 변화: `container <name>: STOPPED → RUNNING`
- 명령 ack: `ctrl start/stop svc`, `ctrl set mode`, `ctrl start/stop ctr`, `ctrl set recovery`, `update list` — 끝에 `SUCCESS` 또는 `FAILED (ret=N)`.

### 색상/badge 의미
| 상태 | 색 |
|---|---|
| RUNNING / 컨테이너 RUNNING | 초록 |
| INITIALIZING / 컨테이너 PAUSED | 노랑 |
| RUNNING_NO_RESPONSE | 주황 |
| TERMINATING | 보라 |
| NOT_RUNNING / 컨테이너 STOPPED | 빨강 |
| UNKNOWN | 회색 |

- **exit 칩(`exit=N`)**: 실제 비정상 종료(0 아님, -1 sentinel 제외)일 때만 표시 = "실패 종료 관찰됨".

## 3. 접속·데이터

- **접속**: `config.json` `rosbridge.url` (기본 `ws://127.0.0.1:9090`). 하트비트 `"running"` → `/app_status/lfc_monitor` 1초.
- **구독**: `NotifyServiceState`(서비스 상태), `NotifyContainerState`(컨테이너 상태+exit), `LifecycleDiagReport`(주기 권위 스냅샷: 상태·recovery_policy·exit_code·container_name), `UpdateServiceListResponse`, `ctrl/*Response`(명령 ack). `GetServiceStateResponse` 는 팬텀 샘플 진동 방지로 **의도적 무시**.
- **발행(폴)**: `GetServiceStateRequest` 를 `pollIntervalSec`(기본 5s)마다.
- 제어 명령은 `lifecycle_mgr` 의 **`ctrl/*` 정책 게이트**를 거침(OTA 모드 등에서 거부될 수 있음).
- (참고: config 의 `knownServices` 프리시드 목록은 UI 에 쓰지 않음 — 백엔드가 실제 보고한 서비스만 표시.)

## 4. 제어 동작

버튼 클릭 시 **즉시 실행(확인 다이얼로그 없음)**, 낙관적 UI + Events 로그.

| 동작 | 위치 | 보내는 요청 |
|---|---|---|
| 컨테이너 시작/정지 | 컨테이너 카드 Start/Stop | `ctrl/StartContainer`·`StopContainer` `{container_list:[name]}` |
| 서비스 시작 | 서비스 행 Start (NOT_RUNNING/RUNNING_NO_RESPONSE 시) | `ctrl/StartService` `{service_list:[name]}` (INITIALIZING 로 낙관표시) |
| 서비스 정지 | 서비스 행 Stop (INITIALIZING/RUNNING 시) | `ctrl/StopService` `{service_list:[name]}` (NOT_RUNNING 로 낙관표시) |
| 복구 정책 변경 | 서비스 행 드롭다운 | `ctrl/SetRecoveryPolicy` `{service_list:[name], recovery_policy}` |
| 서비스 모드(전체) | Settings → Service Mode → NORMAL/OTA_MODE + Apply | `ctrl/SetServiceMode` `{service_list:[전체], service_mode}` |

- **버튼 게이팅**: TERMINATING/UNKNOWN 은 Start·Stop 모두 비활성(전이 중 중복 방지).
- **Recovery 드롭다운**: 선택 가능 = **MANUAL / ALWAYS / ON_FAILURE**. 그 외 정책(DEFAULT/ON_SUCCESS/ON_NOT_RESPONDING)은 현재값을 읽기전용으로만 표시.
- **OTA 모드**: 전 서비스 일괄 NORMAL↔OTA_MODE 전환(개별 모드 없음). SnackBar 로 "서비스 모드 <MODE> 적용 요청" 확인, 결과는 Events 에.

## 5. 상태

- **connected**(초록)/**disconnected**(회색) — 앱바. 500ms 워치독으로 재바인드.
- Empty: "no containers/services yet…", Events "no events yet".
- 오류: 명령 실패 시 Events `… FAILED (ret=N)`. 미연결 중 명령 시 내부 `lastError`="ROS not connected". Settings 에서 잘못된 URL 은 빨강 에러.

## 6. 설정 (config.json / Settings 다이얼로그)

읽기 우선순위: `--config <path>` → `LFC_MONITOR_CONFIG` env → `./config/config.json` → `~/.config/lfc_monitor/config.json` → `/etc/lfc_monitor/config.json` → 기본값.

| 필드 | 의미 | 런타임 편집 |
|---|---|---|
| `rosbridge.url` | rosbridge URL (기본 `ws://127.0.0.1:9090`) | ✅ Settings → URL (Apply/Reset, `ws://`·`wss://` 필수), config.json 에 저장(재시작 유지) |
| `statusTopic` | 하트비트 토픽 (`/app_status/lfc_monitor`) | — |
| `pollIntervalSec` | GetServiceStateRequest 주기 (기본 5, 1~60) | — |
| `knownServices` | 프리시드(현재 UI 미사용) | — |
| `theme` | `light`(기본)/`dark` | ✅ Settings → Theme, 즉시 적용·저장 |

**Settings 다이얼로그**(앱바 톱니): ① rosbridge URL 편집(Apply/Reset), ② Theme Light/Dark, ③ Service Mode(global) NORMAL/OTA_MODE + "Apply to all services".
