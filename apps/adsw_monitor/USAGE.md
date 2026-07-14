# AD SW Monitor 사용 가이드

> 대상: 운전자/운영자 (앱 사용법). 빌드·개발은 [README.md](README.md) 참조.
> 런처(hmi_launcher) 안에서 **"AD SW"**(📡) 카드로 실행되거나 단독 앱으로 실행됩니다.

## 1. 개요

AD SW Monitor 는 **자율주행(Autoware 기반) 소프트웨어 스택의 실시간 상태를 보여주는 읽기 전용 대시보드**입니다. rosbridge WebSocket 으로 차량 ROS2 그래프에 접속해 두 가지를 표시합니다:
- **AD SW 텔레메트리**: 차량 상태·센서·인지(perception)·계획(planning)·측위(localization)·맵
- **진단(diagnosticmgr) 정보**: 미들웨어 진단 알림 스트림 + 진단 항목 목록(PASS/WARNING/FATAL), 보안 이벤트 팝업

> 조작으로 차량을 제어하지 않습니다(모니터링 전용). 제어는 Lifecycle Monitor 참조.

## 2. 화면 구성

상단 헤더: 차 아이콘 + **"AD SW Monitor"** 제목 + 우측 **탭 2개**. 우하단 **로그 버튼(터미널 아이콘)**.

### 탭 1 — "AD SW Info"
3열 **접이식 카드**(기본 접힘, 헤더 탭하면 펼침):

| 열 | 카드 | 표시 항목 |
|---|---|---|
| 1 | **Vehicle** | Steering Tire Angle, Current Velocity(km/h), Gear(N/D/R/P/L), Hazard Light, Turn Indicator, Battery Status |
| 1 | **Sensor** | Number of sensor, IMU orientation covariance |
| 2 | **Perception** | Objects(감지 객체 클래스+확률), Traffic Light |
| 2 | **Planning** | Planning goal x / y / z |
| 3 | **Localization** | Pose X/Y/Z, Twist linear/angular |
| 3 | **Map** | Pointcloud height, width |

- 각 행: 왼쪽 라벨(회색) + 오른쪽 값(선택·복사 가능). **데이터 없으면 `-`**.
- (참고: "Control/Lane Departure" 카드는 소스에 있으나 비활성/주석 처리.)

### 탭 2 — "Diagnostic Info"
- **Diagnostic Notifications**(종 아이콘): 실시간 진단 알림 목록(최신 위). 각 항목에 `status(코드)`, `message`, `source`, `raw_data`, `received_at` 표시. 비어있으면 "Waiting for notifications...".
- **Diagnostic Info Get**(톱니 아이콘): **Refresh 버튼**으로 전체 진단 항목을 조회. 각 항목의 `name`, `status_text`, `code/ret/msg/source/raw` 표시. 초기엔 "Press refresh to load diagnostics".

### Debug Log (로그 버튼 → 하단 시트)
캡처된 로그 라인(최대 800). Auto-follow / 맨아래로 / Clear, 드래그로 크기 조절.

> ⚠️ **상태 색 인디케이터 없음**: PASS/WARNING/FATAL 에 따른 초록/노랑/빨강 dot 렌더 코드는 현재 **주석 처리**되어 있어, 값은 상태와 무관하게 일반 텍스트 색으로 표시됩니다. 상태는 값(예: `status: WARNING (3)`) 텍스트로 확인하세요.

## 3. 접속·데이터 소스

- **접속**: `config.json` 의 `rosbridge.url` (번들 기본 `ws://172.16.10.48:9090`, 폴백 `ws://127.0.0.1:9090`). 재연결 자동(백오프 1s→8s).
- **하트비트**: `std_msgs/String "running"` 을 `/app_status/adsw_monitor` 에 1초마다 발행(런처 liveness 감지용).

주요 구독 토픽(탭1): `/api/vehicle/status`, `/vehicle/status/velocity_status`, `/vehicle/status/battery_charge`, `/sensing/number_of_sensor`, `/sensing/imu/imu_data`, `/api/perception/objects`, `/perception/.../traffic_signals`, `/planning/path_candidate/goal_planner`, `/localization/kinematic_state`, `/map/pointcloud_map`, `/diagnostics`.

진단(탭2): `/mmf/diagnosticmgr/DiagnosticInfoListRequest`·`DiagnosticInfoRequest` 발행 → `...ListResponse`·`...Response`·`DiagnosticNotification` 구독. 알림 텍스트에 "security" 계열 포함 시 **보안 경고 팝업**.

## 4. 조작

- **탭 전환**: "AD SW Info" / "Diagnostic Info" (두 탭 상태 유지).
- **카드 접기/펼치기**: 카드 헤더 탭.
- **진단 새로고침**: "Diagnostic Info Get" 의 Refresh (진행 중 비활성).
- **값 복사**: 값은 선택 가능(SelectableText).
- **다이얼로그**: 차선이탈 경고(Lane departure), 보안 경고(Security Alert) — OK 로 닫음(여러 개면 순차 표시).
- **로그**: 우하단 버튼 → Debug Log 시트.
- 수동 연결/해제·필터·검색은 없음. 재연결 자동.

## 5. 상태 표시

- **연결/미연결 배너 없음** — 미연결 시 값이 갱신 안 되고 마지막 값 또는 `-` 유지.
- Empty: 텔레메트리 `-`, 알림 "Waiting for notifications...", 진단 "Press refresh...", 로그 "No logs yet...".
- 새로고침 중: Refresh 버튼이 스피너로 바뀌고 비활성.
- 오류: 내부 `lastError` 는 UI 에 직접 표시되지 않음 — 목록이 비어있거나 Debug Log 로 확인.
- **(웹 실행 시)** 첫 실행에 "ROS Bridge 주소 입력" 다이얼로그 → 입력값 브라우저에 저장.

## 6. 설정 (config.json)

파일: `config/config.json` (번들 asset). 필드:
- **`rosbridge.url`** — 접속할 rosbridge WebSocket (가장 중요).
- **`statusTopic`** — 하트비트 발행 토픽 (기본 `/app_status/adsw_monitor`).

읽기 우선순위(네이티브): `ADSW_CONFIG` env → `$XDG_CONFIG_HOME/adsw_monitor/config.json` 또는 `~/.config/adsw_monitor/config.json` → `/etc/adsw_monitor/config.json` → 번들 `<실행경로>/config/config.json`. 변경 후 앱 재시작 시 반영.

> 참고: 테마 라이트/다크는 정의돼 있으나 **앱 내 토글 없음**(기본 light). 런처에서 실행 시 런처 Settings 의 "App Theme → AD SW" 로 조정 가능.
