# Diagnostic Monitor 사용 가이드

> 대상: 운전자/운영자 (앱 사용법). 빌드·개발은 [README.md](README.md) 참조.
> 런처(hmi_launcher) 안에서 **"Diagnostic Monitor"**(🩺) 카드로 실행되거나 단독 앱으로 실행됩니다.
> 원래 `adsw_monitor` 의 "Diagnostic Info" 탭이었고, 기능별 앱 분리로 독립 앱이 되었습니다.

## 1. 개요

Diagnostic Monitor 는 **MMF 미들웨어 진단(`diagnosticmgr`) 정보를 보여주는 읽기 전용 대시보드**입니다.
rosbridge WebSocket 으로 차량 ROS2 그래프에 접속해 진단 알림 스트림과 진단 항목
목록(PASS/WARNING/FATAL), 보안 이벤트 팝업을 표시합니다.

> 조작으로 차량을 제어하지 않습니다(모니터링 전용). 제어는 Lifecycle Monitor 참조.
> AD SW(Autoware) 텔레메트리는 별도 앱 **ADSW Monitor**(📡)에서 봅니다.

## 2. 화면 구성

상단 헤더: 하트 모니터 아이콘 + **"Diagnostic Monitor"** 제목. 우하단 **로그 버튼(터미널 아이콘)**.
탭 없는 **단일 뷰**로 아래 두 카드를 표시합니다.

- **Diagnostic Notifications**(종 아이콘): 실시간 진단 알림 목록(최신 위). 각 항목에 `status(코드)`, `message`, `source`, `raw_data`, `received_at` 표시. 비어있으면 "Waiting for notifications...".
- **Diagnostic Info Get**(톱니 아이콘): **Refresh 버튼**으로 전체 진단 항목을 조회. 각 항목의 `name`, `status_text`, `code/ret/msg/source/raw` 표시. 초기엔 "Press refresh to load diagnostics".

### Debug Log (로그 버튼 → 하단 시트)
캡처된 로그 라인(최대 800). Auto-follow / 맨아래로 / Clear, 드래그로 크기 조절.

> ⚠️ **상태 색 인디케이터 없음**: PASS/WARNING/FATAL 에 따른 초록/노랑/빨강 dot 렌더 코드는 현재 **주석 처리**되어 있어, 값은 상태와 무관하게 일반 텍스트 색으로 표시됩니다. 상태는 값(예: `status: WARNING (3)`) 텍스트로 확인하세요.

## 3. 접속·데이터 소스

- **접속**: `config.json` 의 `rosbridge.url` (번들 기본 `ws://172.16.10.48:9090`, 폴백 `ws://127.0.0.1:9090`). 재연결 자동(백오프 1s→8s).
- **하트비트**: `std_msgs/String "running"` 을 `/app_status/diag_monitor` 에 1초마다 발행(런처 liveness 감지용).

진단 경로: `/mmf/diagnosticmgr/DiagnosticInfoListRequest`·`DiagnosticInfoRequest` 발행 → `...ListResponse`·`...Response`·`DiagnosticNotification` 구독. 알림 텍스트에 "security" 계열 포함 시 **보안 경고 팝업**.

메시지 정의는 이 앱의 [`diagnosticmgr/`](diagnosticmgr) ROS 패키지에 있습니다.

## 4. 조작

- **카드 접기/펼치기**: 카드 헤더 탭.
- **진단 새로고침**: "Diagnostic Info Get" 의 Refresh (진행 중 비활성).
- **값 복사**: 값은 선택 가능(SelectableText).
- **다이얼로그**: 보안 경고(Security Alert) — OK 로 닫음(여러 개면 순차 표시).
- **로그**: 우하단 버튼 → Debug Log 시트.
- 수동 연결/해제·필터·검색은 없음. 재연결 자동.

## 5. 상태 표시

- **연결/미연결 배너 없음** — 미연결 시 값이 갱신 안 되고 마지막 값 또는 `-` 유지.
- Empty: 알림 "Waiting for notifications...", 진단 "Press refresh...", 로그 "No logs yet...".
- 새로고침 중: Refresh 버튼이 스피너로 바뀌고 비활성.
- 오류: 내부 `lastError` 는 UI 에 직접 표시되지 않음 — 목록이 비어있거나 Debug Log 로 확인.
- **(웹 실행 시)** 첫 실행에 "ROS Bridge 주소 입력" 다이얼로그 → 입력값 브라우저에 저장.

## 6. 설정 (config.json)

파일: `config/config.json` (번들 asset). 필드:
- **`rosbridge.url`** — 접속할 rosbridge WebSocket (가장 중요).
- **`statusTopic`** — 하트비트 발행 토픽 (기본 `/app_status/diag_monitor`).

읽기 우선순위(네이티브): `DIAG_CONFIG` env → `$XDG_CONFIG_HOME/diag_monitor/config.json` 또는 `~/.config/diag_monitor/config.json` → `/etc/diag_monitor/config.json` → 번들 `<실행경로>/config/config.json`. 변경 후 앱 재시작 시 반영.

> 참고: 테마 라이트/다크는 정의돼 있으나 **앱 내 토글 없음**(기본 light). 런처에서 실행 시 런처 Settings 의 "App Theme → Diagnostic Monitor" 로 조정 가능.
