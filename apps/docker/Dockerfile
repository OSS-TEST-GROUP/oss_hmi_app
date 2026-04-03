FROM ubuntu:22.04

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
ADD output/adsw_monitor-x86_64-release.tar.gz /app/

# config.json 복사 (실행파일 옆 config/ 경로로 — config_loader_io.dart 5번 경로)
COPY adsw_monitor/config/config.json /app/config/config.json

# 실행 권한 설정
RUN chmod +x /app/adsw_monitor

# Wayland 또는 X11 환경 변수 (런타임에서 주입)
ENV XDG_RUNTIME_DIR=/tmp/runtime
ENV DISPLAY=:0

ENTRYPOINT ["/app/adsw_monitor"]
