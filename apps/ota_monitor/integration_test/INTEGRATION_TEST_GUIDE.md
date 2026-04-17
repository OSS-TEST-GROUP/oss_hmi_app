# OTA Monitor Integration Test Guide

## 1. 개요

`integration_test/` 디렉터리에 있는 통합 테스트는 MockOtaManager(rosbridge WebSocket 서버)를 통해
실제 roslibdart → OtaCollector → UI 전체 파이프라인을 검증한다.

단위 테스트(`test/`)가 각 컴포넌트를 격리하여 검증하는 것과 달리,
통합 테스트는 실제 WebSocket 통신과 GetX 상태 관리를 포함한 end-to-end 흐름을 확인한다.

---

## 2. 파일 구성

```
integration_test/
  mock_ota_manager.dart        # Mock rosbridge WebSocket 서버 (dart:io)
  ota_integration_test.dart    # Linux 통합 테스트 (mock ↔ roslibdart ↔ UI)
  ota_web_test.dart            # Chrome 통합 테스트 (seed 기반 UI 검증, F011)
  INTEGRATION_TEST_GUIDE.md    # 이 문서
```

---

## 3. 실행 방법

### 3.1 기본 실행

```bash
cd apps/ota_monitor
DISPLAY=:1 flutter test integration_test/ -d linux
```

### 3.2 특정 테스트만 실행

```bash
# 테스트 이름의 일부를 --name 옵션에 지정
DISPLAY=:1 flutter test integration_test/ -d linux --name "App List"
DISPLAY=:1 flutter test integration_test/ -d linux --name "업데이트 확인"
DISPLAY=:1 flutter test integration_test/ -d linux --name "sendNotifyStatus"
```

### 3.3 사전 조건

- Linux desktop 타겟 빌드 환경 (flutter linux 지원)
- Xvfb 또는 실제 디스플레이 (`DISPLAY` 환경변수)
- `pubspec.yaml`에 `integration_test: sdk: flutter` 포함

### 3.4 Web (Chrome) 실행 — F011

브라우저 런타임에서는 `dart:io` HttpServer를 쓸 수 없어 MockOtaManager가 동작하지 않는다.
`ota_web_test.dart`는 그 대신 `OtaCollector`에 seed 데이터를 미리 주입해 UI 레이어의
웹 호환성을 확인한다.

1. 사전 설치:
   ```bash
   # chromedriver 버전은 현재 Chrome과 일치해야 한다
   # 예) Chrome 133 → chromedriver 133.x
   chromedriver --port=4444 &
   ```

2. 드라이버 실행:
   ```bash
   cd apps/ota_monitor
   flutter drive \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/ota_web_test.dart \
     -d chrome
   ```

3. CI에서는 headless 모드:
   ```bash
   chromedriver --port=4444 --headless &
   flutter drive \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/ota_web_test.dart \
     -d web-server --browser-name=chrome
   ```

`test_driver/integration_test.dart`는 표준 부트스트랩 파일로 아래 내용이 있어야 한다:
```dart
import 'package:integration_test/integration_test_driver.dart';
Future<void> main() => integrationDriver();
```

현재 리포지토리에는 chromedriver가 셋업되어 있지 않아 이 시나리오는 작성만 해두었다.
실제 환경에서 위 명령을 실행하면 통과해야 한다.

---

## 4. 아키텍처

### 4.1 테스트 구조

```
ota_integration_test.dart
  setUpAll    -- MockOtaManager 서버 시작 (포트 자동 배정)
  tearDownAll -- MockOtaManager 서버 중지

  각 테스트 setUp:
    1. Get.reset()
    2. OtaCollector 생성 및 GetX 등록
    3. RosKeeper 생성 (mock 서버 포트 지정)
    4. rosKeeper.start() 호출

  각 테스트 tearDown:
    1. rosKeeper.stop()
    2. Get.reset()
```

### 4.2 MockOtaManager 동작 방식

MockOtaManager는 `dart:io` HttpServer + WebSocketTransformer를 사용하는
실제 rosbridge 프로토콜(JSON over WebSocket) 서버다.

**처리하는 rosbridge op:**

| op        | 처리 내용 |
|-----------|-----------|
| subscribe | otaResponseTopics[4] 구독 시 80ms 후 초기 앱 상태 3건 브로드캐스트 |
| publish   | 요청 토픽별 응답 브로드캐스트 |
| advertise | 무시 |

**초기 앱 데이터:**

| 이름          | status  | settings                                | state   |
|---------------|---------|-----------------------------------------|---------|
| NavigationApp | Synced  | `{"auto_update":true,"interval":3600}`  | idle    |
| MapUpdater    | idle    | `{"schedule":"daily","max_size_mb":500}` | ready   |
| SensorFusion  | Unknown | `{}`                                    | standby |

**SetAppUpdate 응답 타이밍:**

```
t=0ms   : SetAppUpdateResponse (ret_code: 1)
t=150ms : NotifyAppUpdateStatus (status: updating)
t=350ms : NotifyAppUpdateStatus (status: complete)
```

### 4.3 요청/응답 토픽 매핑

```
otaRequestTopics[0]   GetAppUpdateSettings   →  otaResponseTopics[0]  GetAppUpdateSettingsResponse
otaRequestTopics[1]   SetAppUpdateSettings   →  otaResponseTopics[1]  SetAppUpdateSettingsResponse
otaRequestTopics[2]   GetAppUpdateState      →  otaResponseTopics[2]  GetAppUpdateStateResponse
otaRequestTopics[3]   SetAppUpdate           →  otaResponseTopics[3]  SetAppUpdateResponse
                                             →  otaResponseTopics[4]  NotifyAppUpdateStatus (updating, complete)
otaResponseTopics[4]  (subscribe)            →  NotifyAppUpdateStatus (초기 상태 3건)
```

---

## 5. 테스트 케이스 목록 (총 17개)

### 5.1 App List (3개)

| 번호 | 테스트명 | 검증 내용 |
|------|----------|-----------|
| 1 | 연결 후 초기 앱 3개가 목록에 표시된다 | NavigationApp, MapUpdater, SensorFusion 텍스트 확인 |
| 2 | 각 앱의 초기 상태 텍스트가 표시된다 | Synced, idle 상태값 UI 표시 확인 |
| 3 | App List 헤더에 앱 개수가 표시된다 | "App List (3)" 타이틀 확인 |

### 5.2 App Details (6개)

| 번호 | 테스트명 | 검증 내용 |
|------|----------|-----------|
| 4 | 앱을 선택하면 App Details 타이틀에 앱 이름이 표시된다 | "App Details: NavigationApp" 텍스트 확인 |
| 5 | 앱 선택 후 settings가 로드되어 UI에 표시된다 | collector.topicData 및 UI에서 auto_update 확인 |
| 6 | 앱 선택 후 state가 로드되어 UI에 표시된다 | collector.topicData['NavigationApp_state'] == 'idle' |
| 7 | 앱 선택 시 GetAppUpdateSettings, GetAppUpdateState 요청이 전송된다 | mock.receivedRequests 토픽 포함 여부 확인 |
| 8 | Refresh Settings 버튼을 누르면 settings가 다시 요청된다 | 요청 횟수 증가 확인 |
| 9 | Refresh State 버튼을 누르면 state가 다시 요청된다 | 요청 횟수 증가 확인 |

### 5.3 Update History (6개)

| 번호 | 테스트명 | 검증 내용 |
|------|----------|-----------|
| 10 | 업데이트 요청 확인 다이얼로그가 표시된다 | 다이얼로그 표시 및 취소 동작 확인 |
| 11 | 업데이트 확인 후 updateHistory에 Update requested 항목이 기록된다 | app_name, ret_code 확인 |
| 12 | 업데이트 후 updating, complete 상태가 히스토리에 순서대로 기록된다 | updateHistory 내 Status: updating, Status: complete 포함 확인 |
| 13 | 업데이트 완료 후 앱 상태가 complete로 변경된다 | topicData 및 appList status 확인 |
| 14 | 히스토리 항목이 Update History 패널에 UI로 표시된다 | 패널 내 NavigationApp 텍스트 존재 확인 |
| 15 | 다른 앱(MapUpdater)의 업데이트도 올바르게 히스토리에 기록된다 | MapUpdater 항목 기록 확인 |

### 5.4 수동 상태 주입 (2개)

| 번호 | 테스트명 | 검증 내용 |
|------|----------|-----------|
| 16 | sendNotifyStatus로 임의 앱을 목록에 추가할 수 있다 | 새 앱 TestInjectedApp UI 표시 확인 |
| 17 | sendNotifyStatus로 기존 앱 상태를 변경할 수 있다 | NavigationApp status 변경 확인 |

---

## 6. 공통 헬퍼 함수

### 6.1 waitUntil

```dart
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxAttempts = 60,
}) async
```

- 조건이 true가 될 때까지 최대 `maxAttempts × 100ms` 대기
- 각 시도마다 `Future.delayed(100ms)` + `tester.pump()` 호출
- 기본 최대 대기 시간: 6초 (60회 × 100ms)

### 6.2 suppressOverflowErrors

```dart
void suppressOverflowErrors()
```

- Xvfb 등 테스트 환경의 작은 화면으로 인한 `RenderFlex overflowed` 오류를 억제
- `addTearDown`으로 테스트 종료 시 원래 핸들러를 자동 복원
- App Details, Update History, 수동 상태 주입 테스트에 적용

### 6.3 setTestSurface

```dart
void setTestSurface(WidgetTester tester)
```

- `tester.view.physicalSize = Size(1920, 1080)`, `devicePixelRatio = 1.0` 설정
- `addTearDown`으로 테스트 종료 시 원래 크기로 자동 복원
- App Details, Update History, 수동 상태 주입 테스트에 적용

### 6.4 selectApp (Update History 내부 헬퍼)

```dart
Future<void> selectApp(WidgetTester tester, String appName) async
```

- Update History 그룹 전용 공통 셋업 헬퍼
- setTestSurface + suppressOverflowErrors 적용
- 앱 목록 로드 대기 → 앱 탭 → settings 로드 완료 대기

---

## 7. 구현 시 주의 사항

### 7.1 다이얼로그 confirm 버튼 tap

AlertDialog의 title과 confirm 버튼이 모두 "확인" 텍스트를 사용하므로
`find.text('확인')` 단독 사용 시 `Found 2 widgets` 오류가 발생한다.

```dart
// 잘못된 방법
await tester.tap(find.text('확인'));

// 올바른 방법 -- .last가 버튼을 가리킴
await tester.tap(find.text('확인').last);
```

### 7.2 updateHistory의 waitUntil 조건

`onNotifyStatus`는 초기 상태 메시지(Synced, idle, Unknown)도 `updateHistory`에 추가하므로
`updateHistory.isNotEmpty` 조건은 업데이트 요청 전에 이미 충족된다.

```dart
// 잘못된 방법 -- 초기 상태 메시지로 인해 즉시 충족됨
await waitUntil(tester, () => collector.updateHistory.isNotEmpty);

// 올바른 방법 -- 특정 메시지 존재 여부로 조건 지정
await waitUntil(tester, () => collector.updateHistory
    .any((e) => e['message'] == 'Update requested'));

await waitUntil(tester, () => collector.updateHistory
    .any((e) => e['message'] == 'Status: complete'));
```

### 7.3 연속 실행 시 브로드캐스트 수신 불안정

17개 테스트를 연속 실행하면 WebSocket 재연결 타이밍에 따라
특정 브로드캐스트가 수신되지 않을 수 있다.
이 경우 수신 확인까지 반복 송신하는 패턴을 사용한다.

```dart
// 수신 확인될 때까지 재전송
await waitUntil(tester, () {
  if (collector.topicData['NavigationApp_status'] == 'error') return true;
  mock.sendNotifyStatus('NavigationApp', 'error');
  return false;
}, maxAttempts: 60);
```

### 7.4 RenderFlex 오버플로 처리

App Details 패널은 KeyValueItem 행이 많을 때 작은 렌더 표면에서 오버플로가 발생한다.
이는 앱 로직 버그가 아닌 테스트 환경 제약이므로 다음 두 가지를 함께 적용한다.

1. `setTestSurface(tester)` -- 1920x1080 렌더 표면 확보
2. `suppressOverflowErrors()` -- 잔여 오버플로 오류 억제

---

## 8. MockOtaManager API

### 8.1 서버 생명주기

```dart
final mock = MockOtaManager();
await mock.start();   // OS가 포트 자동 배정
int port = mock.port; // 서버 포트 조회
await mock.stop();    // 서버 및 모든 클라이언트 연결 종료
```

### 8.2 요청 로그

```dart
// 클라이언트가 publish한 모든 메시지를 기록
List<Map<String, dynamic>> mock.receivedRequests

// 테스트 간 초기화
mock.receivedRequests.clear();

// 특정 토픽 요청 횟수 확인 예시
final count = mock.receivedRequests
    .where((r) => r['topic'] == otaRequestTopics[0])
    .length;
```

### 8.3 수동 상태 주입

```dart
// NotifyAppUpdateStatus 메시지를 직접 브로드캐스트
mock.sendNotifyStatus(String appName, String status);

// 예시
mock.sendNotifyStatus('NavigationApp', 'error');
mock.sendNotifyStatus('NewApp', 'idle');
```

---

## 9. 의존성

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

`MockOtaManager`는 외부 패키지 없이 `dart:io`, `dart:convert`, `dart:async`만 사용한다.
