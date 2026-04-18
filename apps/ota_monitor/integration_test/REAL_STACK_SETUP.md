# 실제 rosbridge + DDS 통합 테스트 실행 가이드 (F013)

이 문서는 `integration_test/ota_integration_test.dart` 를 **실제 rosbridge_server + DDS
스택**으로 돌리고 싶을 때 필요한 인프라와 실행 절차를 정리한다. 현재 리포지토리의
기본 통합 테스트는 Dart 내부의 `MockOtaManager`(WebSocket 서버)로만 돌아가며 DDS
구간은 검증하지 않는다.

---

## 1. 왜 별도 mock이 필요한가

```
Flutter app ─(WebSocket)─▶ rosbridge_server ─(DDS)─▶ ??? ◀─(DDS)─ OtaManager (실제)
```

rosbridge_server 는 중계기일 뿐이므로, 반대편에 요청을 받아 응답을 내보내는 **DDS
참여자**(OtaManager 혹은 mock)가 반드시 있어야 한다. 본 세션에서는
`integration_test/ota_manager_mock.py` 를 rclpy 기반으로 스켈레톤만 준비해 두었다.

---

## 2. 사전 조건

| 도구 / 패키지 | 버전 기준 | 확인 명령 |
|---|---|---|
| ROS2 | Humble 또는 Jazzy | `ros2 --help` |
| `rosbridge_suite` | distro 기본 | `apt show ros-humble-rosbridge-suite` |
| `rclpy` | distro 번들 또는 `pip install rclpy` | `python3 -c "import rclpy"` |
| `mmf_interfaces` | obigo 사내 패키지 | `ros2 interface show mmf_interfaces/msg/GetAppUpdateSettings` |
| Xvfb 또는 실제 디스플레이 | - | `echo $DISPLAY` |
| Flutter | `3.41.2+` | `flutter --version` |

`mmf_interfaces` 는 pub.dev 외부 사내 리포지토리에 존재한다고 가정한다. 해당 워크스페이스
를 빌드해서 `install/setup.bash` 를 source 해야 `ota_manager_mock.py` 의 `from
mmf_interfaces.msg import ...` 가 성공한다.

---

## 3. 실행 시퀀스

### 3.1 인프라 2개 프로세스 기동

```bash
# 터미널 A — rosbridge WebSocket 서버 (기본 포트 9090)
source /opt/ros/humble/setup.bash
source <your-ros-ws>/install/setup.bash   # mmf_interfaces 경로
ros2 run rosbridge_server rosbridge_websocket

# 터미널 B — OtaManager mock (rclpy 노드)
source /opt/ros/humble/setup.bash
source <your-ros-ws>/install/setup.bash
cd hmi/oss_hmi_app/apps/ota_monitor
python3 integration_test/ota_manager_mock.py
# 출력 예: "ota_manager_mock ready — 3 seeded apps"
```

### 3.2 Flutter 통합 테스트 실행 — dart-define 사용 (✅ 구현 완료)

`ota_integration_test.dart` 상단에 이미 스위치가 들어가 있다:

```dart
const String _otaRosUrlOverride =
    String.fromEnvironment('OTA_ROS_URL', defaultValue: '');
final bool _useRealStack = _otaRosUrlOverride.isNotEmpty;
```

- `_useRealStack == false` (기본) → 기존 `MockOtaManager` 경로 그대로 사용.
- `_useRealStack == true` → `MockOtaManager` setUp/tearDown 전부 스킵하고
  `AppConfig.rosUrl = Uri.parse(_otaRosUrlOverride)` 로 실제 rosbridge 에 접속.

실행:
```bash
# Mock 모드 (기존, 17/17 PASS)
DISPLAY=:99 flutter test integration_test/ota_integration_test.dart -d linux

# Real-stack 모드 (F013)
DISPLAY=:99 flutter test integration_test/ota_integration_test.dart -d linux \
    --dart-define=OTA_ROS_URL=ws://localhost:9090
```

### 3.3 Mock-전용 어서션 (real 모드에서 자동 skip)

`mock.receivedRequests` 또는 `mock.sendNotifyStatus` 를 직접 참조하는 어서션은
real 모드에서 의미가 없으므로 **각 testWidgets 상단에 `if (_useRealStack) return;`**
으로 분기해 스킵된다. 현재 skip 대상:

| group | title | 라인 | 이유 |
|---|---|---|---|
| App Details | 앱 선택 시 GetAppUpdateSettings/State 요청 전송 | 227 | `mock.receivedRequests` |
| App Details | Refresh Settings 버튼 재요청 | 246 | `mock.receivedRequests` |
| App Details | Refresh State 버튼 재요청 | 277 | `mock.receivedRequests` |
| 수동 상태 주입 | sendNotifyStatus 로 임의 앱 추가 | 453 | `mock.sendNotifyStatus` |
| 수동 상태 주입 | sendNotifyStatus 로 상태 변경 | 470 | `mock.sendNotifyStatus` |

→ real 모드에서는 **17 중 12개 어서션이 실행**된다 (App List 3개, App Details 3개,
Update History 3개, 기본 연결·초기화 등).

### 3.4 결과 확인 & 실제 DDS 특이사항

- `NotifyAppUpdateStatus` 수신까지 DDS discovery 지연이 있어 처음 수 백 ms 가
  더 걸릴 수 있다. `waitUntil(maxAttempts: 60)` (6초) 로 충분했다면 그대로
  통과한다. 만약 1-2개 어서션만 간헐적으로 실패하면 `maxAttempts` 를 90 으로
  상향하거나 rosbridge 와 ota_manager_mock 기동 후 **5초 대기** 뒤 flutter test
  를 돌리는 편이 안전하다.
- `ros2 topic echo <응답토픽>` 으로 mock 이 실제 DDS 메시지를 내보내는지를
  직접 확인할 수 있다.

---

## 4. Docker Compose 로 묶어 실행 (✅ 구현 완료)

`apps/docker/docker-compose.yml` 에 **`ota-real-stack`** 프로필로 두 서비스가
추가되어 있다. `build`/`test` 프로필과 분리되어 실수로 함께 뜨지 않는다.

### 4.1 서비스 구성

| 서비스 | 이미지 | 역할 |
|---|---|---|
| `rosbridge` | `ros:humble-ros-base` | 기동 시 `ros-humble-rosbridge-suite` 설치 후 `rosbridge_websocket` 실행 (ws://localhost:9090) |
| `ota_manager_mock` | `ros:humble-ros-base` | `/opt/ros/humble`, `${MMF_WS}/install` source 후 `/mock/ota_manager_mock.py` 실행 |

### 4.2 기동

```bash
# mmf_interfaces 가 빌드된 ROS2 워크스페이스 경로를 export
export MMF_WS=/absolute/path/to/mmf_ws   # 예: ~/ros2_ws

cd hmi/oss_hmi_app/apps/docker
docker compose --profile ota-real-stack up -d rosbridge ota_manager_mock

# 초기 40여 초는 apt-get install 이 걸린다. 준비 완료 확인:
docker compose --profile ota-real-stack logs -f ota_manager_mock
# → "ota_manager_mock ready — 3 seeded apps" 가 찍히면 OK
```

### 4.3 Flutter 테스트 호출 (별도 셸)

```bash
cd hmi/oss_hmi_app/apps/ota_monitor
Xvfb :99 -screen 0 1920x1200x24 &
DISPLAY=:99 flutter test integration_test/ota_integration_test.dart -d linux \
    --dart-define=OTA_ROS_URL=ws://localhost:9090
kill %1
```

### 4.4 정리

```bash
cd hmi/oss_hmi_app/apps/docker
docker compose --profile ota-real-stack down
```

### 4.5 MMF_WS 가 없을 때

`MMF_WS` 를 export 하지 않으면 placeholder 경로(`./.placeholder-mmf-ws/install`)
가 마운트되어 `ota_manager_mock` 컨테이너가 **"/mmf_install/setup.bash 없음"**
경고와 함께 친절히 실패한다. 이 경우 rosbridge 는 정상 기동하므로 Flutter 가
접속은 되지만 어떤 응답도 없다 (DDS 피어 부재). 증상을 보면 workspace 빌드와
`MMF_WS` export 를 먼저 확인한다.

---

## 5. 파일 체크리스트

- [x] `integration_test/ota_manager_mock.py` — rclpy 노드 스켈레톤 (py_compile 통과)
- [x] 본 문서 (`REAL_STACK_SETUP.md`) — 실행 절차 최종판
- [x] `ota_integration_test.dart` 에 dart-define `OTA_ROS_URL` 스위치 추가
      (2026-04-18, mock 모드 17/17 PASS 회귀 확인)
- [x] `apps/docker/docker-compose.yml` 에 `rosbridge` + `ota_manager_mock`
      서비스 추가 (`ota-real-stack` 프로필, 2026-04-18)
- [ ] `ota_manager_mock.py` 의 메시지 필드명이 실제 `mmf_interfaces/msg/*.msg`
      정의와 일치하는지 검증 — **ROS2 환경 준비 후 수행** (ros2 interface show
      명령으로 9개 IDL 확인 후 핸들러 필드명만 조정)
- [ ] `ros2 run rosbridge_server rosbridge_websocket` + mock 기동 후 실제로
      `flutter test --dart-define=OTA_ROS_URL=...` 를 돌려 12+ 어서션 통과
      확인 — **ROS2 환경 준비 후 수행**
- [ ] (optional) `docker/Dockerfile.rosbridge` 를 별도로 만들어 매 기동 시의
      apt-get install 40초 제거

---

## 6. 주의사항

1. **ROS_DOMAIN_ID**: 실제 OtaManager 와 테스트가 같은 도메인에 있어야 토픽이
   매칭된다. 기본값 0 이지만 운영 환경에 따라 다를 수 있으니 `export
   ROS_DOMAIN_ID=<n>` 을 양 터미널에 맞춰 설정.
2. **QoS 미스매치**: `ota_manager_mock.py` 는 `RELIABLE + KEEP_LAST/10` 으로 설정
   돼 있다. 실제 OtaManager 가 `BEST_EFFORT` 을 쓰면 구독이 붙지 않는다. 운영측
   QoS 를 확인하고 필요 시 맞춰라.
3. **보안 rosbridge**: 운영에서 TLS(`wss://`) 나 토큰 인증이 걸려 있으면 테스트용
   instance 는 별도로 띄워야 한다.
