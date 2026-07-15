# vehicle_data_test — Vehicle Data

차량 데이터 API 테스트용 시뮬레이터 앱 (Vehicle Data, 🚗). 차량 데이터 토픽을 조회/표시해
API 동작을 확인하는 개발·검증 도구.

<img width="800" alt="vehicle_data_test 1" src="https://github.com/user-attachments/assets/71f14eb3-9591-4c62-a2da-57b46ce70bdd" />
<img width="800" alt="vehicle_data_test 2" src="https://github.com/user-attachments/assets/0a3f468b-96e5-4c06-9de2-97f977f63775" />

## 개요
- 카테고리: monitoring. 차량 데이터 API 검증용 시뮬레이터.
- ⚠️ **docker 빌드 파이프라인 없음**(compose 서비스·`config/` 없음). 아래 flutter 직접 빌드 사용.

## Standalone 빌드·실행 (Flutter 데스크톱)
> Flutter SDK 필요. `apps/vehicle_data_test/` 에서 실행.

```bash
flutter pub get
flutter run -d linux              # 개발 실행
flutter build linux --release     # 릴리스 번들 → build/linux/x64/release/bundle/
```

## 설정
- 전용 `config.json` 없음. 접속 대상 등은 코드/실행 인자에 의존.

## 문서
- HMI 전체 개요·문서 인덱스: [../../README.md](../../README.md)
