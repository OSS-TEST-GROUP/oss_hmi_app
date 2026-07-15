# OTA Monitor 사용 가이드

> 대상: 운영자. 런처(hmi_launcher) 안에서 **"OTA Monitor"**(📦) 로 실행되거나 단독 앱으로
> 실행됩니다. (기본적으로 런처 Manage Apps 에서 **숨김** — 필요 시 활성화)

## 1. 개요

OTA Monitor 는 차량 **MMF OTA Manager** 를 관측·조작하는 운영/진단 콘솔입니다. rosbridge 로
OTA Manager 에 접속해:
- 등록된 OTA 클라이언트와 그 앱들(소유 클라이언트별 트리)
- 각 앱의 업데이트 상태
- OTA Manager 생존 여부(하트비트)
를 보여주고, **OTA Manager 서비스 호출**(앱 업데이트 설정 조회/변경, 상태 조회, **업데이트 실행**,
클라이언트 등록/삭제)을 수행합니다.

> **단일 화면**입니다(탭 아님). 소스 주석의 "Actor tab / Client tab" 은 실제로는 인라인 패널입니다.

## 2. 화면 구성

### 헤더
- **종료** 화살표(데스크톱에서만 `exit(0)`, 모바일/웹에선 동작 안 함)
- 아이콘 + **"OTA Monitor"** 제목
- **연결 표시**: 초록 "connected" / 노랑 "connecting" / 빨강·회색 "disconnected"
- **ROS 재연결 경고**(노랑 삼각형): **3회 이상 연속 재연결 실패** 시에만 표시("ROS 재연결 N회 실패")
- **Settings** 버튼

### 본문 — 좌/우 2열

#### 좌상 — "App List (N)"
- 헤더에 앱 개수, **Refresh 버튼**(Manager 에서 재조회), `source:` 라벨(`local`=캐시 → `manager`=응답 후 권위)
- 비어있으면: "앱 없음 / Refresh 로 다시 조회하세요"
- **소유 클라이언트별 트리**: `Client #<id> — <name>` 확장 타일(초기 확장), "N app(s)", 우측 **휴지통 아이콘**(클라이언트 삭제, id≥0 일 때만). 소유자 없는 앱은 `Unassigned`(id -1).
- 앱 행: 아이콘 + 앱 이름 + 상태줄. **상태 색**: "complete"/"Synced" → 초록, "fail"/"error" → 빨강, 그 외 → 회색(기본 "Unknown"). 행 탭 시 선택 하이라이트.

#### 좌하 — "Client Interaction"
ROS 준비 전 "Ros connecting… / Client 정보 대기 중". 준비되면 카드 3개:
1. **New Client Registration**: `client_name`(기본 ota_monitor) + `app_list`(콤마구분) + **Register** 버튼 + `client_id:`(등록 결과 id)
2. **Manager Status**: "Ready:" dot(초록 "received" / 회색 "waiting"), 하트비트 stale 시 노랑 "stale" + 타이머 아이콘, `seq=` / `ts=HH:mm:ss.SSS`(stale 시 노랑)
3. **App Update Status (N)**: 수신한 `NotifyAppUpdateStatus` 목록(최신순). 내 `client_id` 매칭 행은 하이라이트(▣ vs □). 비어있으면 "no NotifyAppUpdateStatus messages yet"

#### 우 — "Actor API Call"
카드 4개(각각 입력 + **Send** + 응답 박스):
| 카드 | 입력 | 동작 |
|---|---|---|
| **GetAppUpdateSettings** | app_name | 앱 업데이트 설정 조회 |
| **SetAppUpdateSettings** | app_name + app_settings(JSON) | 설정 변경 |
| **GetAppUpdateState** | app_name | 업데이트 상태 조회 |
| **SetAppUpdate** | app_name | **업데이트 실행(트리거)** |

- 응답 박스: "(no response yet)" → "Sending… id=…"(스피너) → 성공 시 초록 `ret_code: OK` + 본문 / 업무 오류 시 빨강 "✕ …"(ret_code 2=ERROR) / 5초 무응답 시 노랑 "⚠ timeout (5s)".

### Settings 다이얼로그
- **rosbridge WebSocket URL**: 현재값 표시 + 편집(`ws://`·`wss://` 검증) + **Apply**(유효 시 활성) + **Reset to default** + "config.json 에 저장" 안내
- **Theme**: Light / Dark(즉시 적용)

## 3. 접속·데이터

- **접속**: `config.json` `rosbridge.url`(기본 `ws://localhost:9090`). 하트비트 `"running"` → `/app_status/ota_monitor` 발행(런처 liveness 용, UI 에는 표시 안 됨).
- **Actor 서비스**(`/mmf/otamanager/otaactor_service/`): `GetAppList`(Refresh), `GetAppUpdateSettings`/`SetAppUpdateSettings`, `GetAppUpdateState`, `SetAppUpdate`, `DeleteOtaClientRegistration` + 각 `*Response`.
- **Client 서비스**(`/mmf/otamanager/otaclient_service/`): `SetOtaClientRegistration`+Response, `NotifyOtaManagerReady`, `NotifyAppUpdateStatus`.
- **하트비트**: `/mmf/otamanager/diagnostic_service/NotifyOtaMgrHeartbeat`(`seq`,`timestamp_ms`) → seq/ts 표시 + **manager-ready 판정의 권위 신호**.
- App List 트리는 `GetAppListResponse` 의 `app_names`/`owner_client_ids`/`owner_client_names` 로 구성(요청은 `{id}` 만, 필터 없음).

## 4. 조작

- **앱 선택**(행 탭): 우측 Actor 카드의 `app_name` 자동 채움 + GetAppUpdateSettings·GetAppUpdateState 자동 실행.
- **Refresh**: GetAppList. 5초 무응답 시 "앱 목록 조회 시간 초과 — 로컬 캐시 사용".
- **클라이언트 삭제**(휴지통): 확인 다이얼로그("… 등록 및 모든 앱을 삭제할까요?" 취소/삭제) → 서버 반영 + 트리 자동 갱신.
- **Actor 호출**(Send): 필드 입력 → Send. **SetAppUpdate 는 확인 없이 즉시 실행**. 진행 중·미준비·app_name 빈값이면 Send 비활성.
- **클라이언트 등록**(Register): 콤마 구분 앱 목록 파싱 후 등록(확인 없음).
- **Settings Apply**: URL 검증·저장 후 ROS 재연결("재연결 중..." / "잘못된 URL 형식입니다"). Theme 즉시 적용.
- 미연결 중 호출 시: "ROS에 연결되지 않음 — 잠시 후 다시 시도하세요".

## 5. 상태

- **연결**: connected / connecting / disconnected. 자동 재연결 백오프(1→2→4→8s), 3회+ 실패 시 헤더 경고.
- **Manager Ready**: **첫 하트비트 수신 후** true(late-join 안전). `NotifyOtaManagerReady` 는 best-effort 빠른 경로일 뿐. → 초록 "received" / 회색 "waiting".
- **하트비트 stale**: 9초(3×3s) 무수신 또는 첫 수신 전 → 노랑 "stale".
- **App-list source**: local(캐시) → manager(권위, 응답 후).
- **요청 상태(Actor)**: pending(스피너) / OK(초록) / 오류(✕ 빨강) / 5초 timeout(노랑). (내부 요청 만료 sweep 30초.)
- Empty: App List "앱 없음", Client "Ros connecting…", App Update Status "no messages yet", Actor "(no response yet)".

## 6. 설정 (config.json)

읽기 우선순위: `OTA_CONFIG` env → `$XDG_CONFIG_HOME/ota_monitor/config.json` 또는 `~/.config/ota_monitor/config.json` → `/etc/ota_monitor/config.json` → 번들 `<실행경로>/config/config.json`.

주요 필드: `rosbridge.url`(기본 `ws://localhost:9090`), `statusTopic`(`/app_status/ota_monitor`), `initialApps`(시작 시 앱목록 시드), `rosReconnectIntervalSec`(2), `heartbeatIntervalSec`(1), `historySize`(20), `theme`(light/dark). **런타임 편집 가능**: URL(Settings→Apply), Theme(Settings) — 같은 파일에 저장(재시작 유지).

## 7. 주의 / 오해 포인트

- **탭 없음** — 좌/우 인라인 패널 구조(주석의 "tab" 은 관례적 표현).
- **Debug Log 오버레이·일부 위젯(DataViewWidget/KeyValueItem)·팔레트 액션색**은 소스에 있으나 **UI 에서 접근 불가/미사용**(dead code) — 사용 기능으로 오해 금지.
- 종료 화살표는 **데스크톱에서만** 동작.
- 런처에서 이 앱은 **기본 숨김**(Manage Apps 에서 켜야 홈에 표시).
