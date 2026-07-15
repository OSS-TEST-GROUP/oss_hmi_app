# oss_launcher_bot — Launcher Bot

런처의 **AI 어시스턴트("Launcher Bot", 🤖)**. 자연어로 앱을 열고 질의응답을 수행한다.
동일 기능이 hmi_launcher 에 내장(런처봇 패널)되어 있고, 이 디렉토리는 그 **standalone 앱**이다.

## 개요
- 카테고리: assistant. v_agentos AI 데몬(gRPC, 기본 `localhost:50051`) 연동 — 데몬 없으면 기능 제한.
- manifest 의 `prompts`(자연어 발화)로 앱 실행 라우팅.
- ⚠️ **docker 빌드 파이프라인 없음**(compose 서비스·`config/` 없음). 아래 flutter 직접 빌드 사용.

## Standalone 빌드·실행 (Flutter 데스크톱)
> Flutter SDK 필요. `apps/oss_launcher_bot/` 에서 실행.

```bash
flutter pub get
flutter run -d linux              # 개발 실행
flutter build linux --release     # 릴리스 번들 → build/linux/x64/release/bundle/
```

- arm64(AGL) 타겟은 별도 AOT 툴체인이 필요하며, 실제 배포는 보통 **hmi_launcher 에 임베드된 런처봇**으로 제공된다.

## 설정
- 전용 `config.json` 없음. AI 데몬 주소 등은 코드/환경(v_agentos)에 의존.
- 런처 내장 런처봇의 활성/비활성: hmi_launcher 의 `LAUNCHER_BOT_ENABLED` 및 상단바 Standard↔AI SDK 참조 → [../hmi_launcher/SETTINGS_USAGE.md](../hmi_launcher/SETTINGS_USAGE.md)

## 문서
- 런처 통합/AI SDK: [../hmi_launcher/README.md](../hmi_launcher/README.md), [../hmi_launcher/SETTINGS_USAGE.md](../hmi_launcher/SETTINGS_USAGE.md)
