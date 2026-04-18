FROM ubuntu:22.04

# 재사용 가능한 런타임 이미지. 다른 Flutter 앱에도 같은 Dockerfile 을
# 사용하려면 --build-arg APP_NAME=<pubspec name> 으로 호출한다.
#
# 예)
#   docker build -f docker/Dockerfile --build-arg APP_NAME=ota_monitor \
#                -t ota_monitor:x86_64 .
ARG APP_NAME=adsw_monitor
ENV APP_NAME=${APP_NAME}

# GTK, Wayland, OpenGL 관련 런타임 라이브러리 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 \
    libglib2.0-0 \
    libepoxy0 \
    libfontconfig1 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libharfbuzz0b \
    libatk1.0-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libwayland-client0 \
    libwayland-egl1 \
    libwayland-cursor0 \
    libxkbcommon0 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxrandr2 \
    libxi6 \
    libegl1 \
    libgl1 \
    libgl1-mesa-dri \
    libgles2 \
    libdbus-1-3 \
    fonts-noto \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 앱 번들 추출 (tar.gz → /app/)
WORKDIR /app
ADD output/${APP_NAME}-x86_64-release.tar.gz /app/

# config.json 복사 (실행파일 옆 config/ 경로로 — config_loader_io.dart 5번 경로)
COPY ${APP_NAME}/config/config.json /app/config/config.json

# 실행 권한 설정 + 고정 엔트리포인트 이름(ENTRYPOINT exec form 은
# 변수 확장을 지원하지 않으므로 심볼릭 링크로 우회한다).
RUN chmod +x /app/${APP_NAME} && ln -sf /app/${APP_NAME} /app/entrypoint

# Wayland 또는 X11 환경 변수 (런타임에서 주입)
ENV XDG_RUNTIME_DIR=/tmp/runtime
ENV DISPLAY=:0

ENTRYPOINT ["/app/entrypoint"]
