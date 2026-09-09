# vehicle_data_app — Vehicle Data

차량 데이터(VISS v3.0) API 검증용 앱 (`Vehicle Data`, 🚗). **VISS gRPC 서버와 클라이언트를
한 프로세스에 함께 담아**, 실제 차량이나 MMF 없이도 구독·조회 동작을 확인할 수 있다.

<img width="800" alt="vehicle_data_test 1" src="https://github.com/user-attachments/assets/71f14eb3-9591-4c62-a2da-57b46ce70bdd" />
<img width="800" alt="vehicle_data_test 2" src="https://github.com/user-attachments/assets/0a3f468b-96e5-4c06-9de2-97f977f63775" />

## 구조

앱이 뜨면 **먼저 gRPC 서버를 `0.0.0.0:50052` 로 띄우고**([main.dart:17](lib/main.dart#L17)),
화면은 그 서버에 클라이언트로 붙는다(기본 `127.0.0.1:50052`). 그래서 외부 의존 없이
단독으로 동작하며, 화면의 host/port 를 바꾸면 **다른 VISS 서버**에도 붙을 수 있다.

```
assets/csv/*.csv → CsvLoader → CsvPlayback ─(VSS 경로로 변환)→ SimulatorBus
                                   VssMapper ↗                      │
                                                                    ▼
                    화면(ReceiverPage) ◀── gRPC ──  VissService (서버)
                                                   SubscriptionRegistry
```

| 구성요소 | 역할 |
|---|---|
| `services/csv_loader.dart` | CSV 파싱 → 표 |
| `services/csv_playback.dart` | 행을 시간축으로 재생 → `SimulatorBus.pushData` |
| `services/vss_mapper.dart` | CSV 헤더 → VSS 경로 매핑 + 단위 변환(SI 옵션) |
| `services/sim_bus.dart` | 싱글턴 스트림 버스 (마지막 값 보관) |
| `services/data_cache.dart` | 최근 값 캐시 |
| `grpc/grpc_server.dart` | `VissService` — `subscribeRequest` 스트리밍 + 단건 조회 |
| `grpc/subscription_registry.dart` | 구독 ID·경로 관리 |
| `grpc/grpc_isolate.dart` | 서버를 별 isolate 로 — UI 블로킹 방지 |
| `pages/receiver_page.dart` | 접속(host/port)·구독 경로 지정·수신 값 표시 |
| `pages/obd_data_page.dart`, `can_data_page.dart` | OBD·CAN 관점 화면. **앱 라우팅에는 아직 연결돼 있지 않다** — `main.dart` 는 `ReceiverPage` 만 띄운다(위젯 테스트는 `test/pages_test.dart` 에 있다) |

프로토콜 정의는 `protos/VISSv3.0.proto`, 생성 코드는 `lib/src/generated/` 에 있다
(`helloworld.proto` 는 gRPC 연결 확인용 예제).

## 실행

**런처 임베드** — `hmi_launcher` 의 path 의존성으로 함께 패키징된다. 런처에서 `Vehicle Data`
카드로 진입하며, 임베디드 위젯은 `hmi_launcher/lib/presentation/panels/vehicle_data_embedded_panel.dart` 다.
런처 이미지를 다시 만들면 이 앱도 함께 반영된다(`apps/docker/docs/DOCKER_GUIDE.md` §1-2).

**단독 실행** — 전용 Docker 서비스는 없다.

```bash
cd apps/vehicle_data_app
flutter pub get
flutter run -d linux              # 개발 실행
flutter build linux --release     # → build/linux/x64/release/bundle/
```

> 포트 `50052` 를 이미 다른 프로세스가 쓰고 있으면 서버 기동이 실패하고 로그에
> `Failed to start gRPC server:` 가 찍힌다(앱은 계속 뜬다 — 화면에서 외부 서버로 붙으면 된다).

## 설정

전용 `config.json` 은 없다. 접속 대상은 **화면에서 입력**한다(기본 `127.0.0.1` / `50052`,
[receiver_page.dart:23](lib/pages/receiver_page.dart#L23)). 기본값을 바꾸려면 `lib/main.dart`
상단의 `grpcClient` 와 `GrpcServer.instance.start(port:)` 를 고친다.

재생할 데이터는 `assets/csv/` 의 CSV 를 쓴다 — 현재 `test.csv`(차량 신호), `can_test.csv`(CAN).
새 CSV 를 추가하면 `pubspec.yaml` 의 `assets:` 에도 등록해야 한다.

## 테스트

```bash
# 빌더 이미지(Flutter 3.32.5)에서 실행 — 호스트 Flutter 버전과 무관하게 재현된다
cd apps && docker run --rm -v "$PWD":/workspace/apps --user $(id -u):$(id -g) \
  -e HOME=/tmp -e PUB_CACHE=/tmp/.pub-cache --entrypoint bash \
  registry.obigo.com/oss/oss-hmi-builder:x86-flutter3.32.5 \
  -c 'cd /workspace/apps/vehicle_data_app && flutter pub get && flutter test'
```

11 개 테스트 파일 **31 건 통과**, `flutter analyze` 무경고 (2026-09-09 확인).
커버 범위: CSV 로더·재생, VSS 매핑, 시뮬레이터 버스, 데이터 캐시, 구독 레지스트리,
gRPC 서버(ACK + 스트림)·클라이언트, 위젯·페이지.

## 문서

- HMI 전체 개요·문서 인덱스: [../../README.md](../../README.md)
- 빌드·레지스트리 push: [../docker/docs/DOCKER_GUIDE.md](../docker/docs/DOCKER_GUIDE.md)
