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

### 3.2 Flutter 통합 테스트 실행

현재 `ota_integration_test.dart` 는 `MockOtaManager` 를 내부적으로 기동해서
그 포트에 접속한다. 실제 rosbridge 를 쓰려면 호출 지점을 다음 중 하나로 바꾼다.

**A) 임시 포크 (권장 — 스코프 유지)**
`ota_integration_test.dart` 를 복사해 `ota_real_stack_test.dart` 를 새로 만들고
MockOtaManager 관련 setup/teardown 을 제거한 뒤 `AppConfig` 의 `rosUrl` 을
`ws://localhost:9090` 고정으로 둔다.

**B) dart-define 환경변수 지원 추가**
기존 테스트 파일에서 `String.fromEnvironment('OTA_ROS_URL', defaultValue: '')`
를 읽어 비어있지 않으면 mock 대신 실제 URL 을 쓴다. 이 경우 한 파일을 공유 가능.
```dart
const overrideUrl = String.fromEnvironment('OTA_ROS_URL');
final useReal = overrideUrl.isNotEmpty;
```
호출:
```bash
DISPLAY=:99 flutter test \
    integration_test/ota_integration_test.dart \
    -d linux \
    --dart-define=OTA_ROS_URL=ws://localhost:9090
```

### 3.3 결과 확인

정상 시나리오라면 기존 17개 어서션이 그대로 통과해야 한다.
한 가지 차이: 실제 DDS 는 discovery 지연이 있어 처음 `NotifyAppUpdateStatus` 가
들어올 때까지 수백 ms 가 더 걸릴 수 있다. `waitUntil` 기반의 어서션(기존 파일에
이미 존재)이 있으면 대부분 그대로 통과한다.

---

## 4. Docker Compose 로 묶기 (나중에 옵션)

`apps/docker/docker-compose.yml` 에 adsw_monitor 의 arm64 빌드 서비스들이 있다. F013
완전 구현 시 아래 서비스를 추가하면 CI 상에서도 원클릭으로 돌릴 수 있다.

```yaml
  ota_rosbridge:
    image: ros:humble-ros-base
    command: >
      bash -c "source /opt/ros/humble/setup.bash &&
               apt-get install -y ros-humble-rosbridge-server &&
               ros2 run rosbridge_server rosbridge_websocket"
    ports: ["9090:9090"]
    network_mode: host

  ota_manager_mock:
    image: ros:humble-ros-base
    volumes:
      - ../ota_monitor/integration_test:/mock
      - <mmf_interfaces workspace>:/mmf_ws
    command: >
      bash -c "source /opt/ros/humble/setup.bash &&
               source /mmf_ws/install/setup.bash &&
               python3 /mock/ota_manager_mock.py"
    network_mode: host
    depends_on: [ota_rosbridge]
```

두 컨테이너가 올라온 뒤 로컬에서 `flutter test --dart-define=OTA_ROS_URL=ws://localhost:9090`
로 호출하면 된다.

---

## 5. 파일 체크리스트 (현재 세션 기준)

- [x] `integration_test/ota_manager_mock.py` — rclpy 노드 스켈레톤. 문법 검증
      완료(py_compile). rclpy + mmf_interfaces 가 없으면 import 단계에서 친절히
      실패하도록 `try/except` 처리.
- [x] 본 문서 (`REAL_STACK_SETUP.md`) — 실행 절차.
- [ ] `ota_manager_mock.py` 의 메시지 필드명이 실제 `mmf_interfaces/msg/*.msg`
      정의와 일치하는지 검증 — **다음 세션에서 해야 함**.
- [ ] `ota_real_stack_test.dart` 또는 dart-define 플래그 지원 — **다음 세션**.
- [ ] `apps/docker/docker-compose.yml` 에 rosbridge + ota_manager_mock 서비스
      추가 — **다음 세션**.

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
