FROM ubuntu:22.04

# Reusable runtime image. To use this Dockerfile for another Flutter app,
# invoke it with --build-arg APP_NAME=<pubspec name>.
#
# Example:
#   docker build -f docker/Dockerfile --build-arg APP_NAME=ota_monitor \
#                -t ota_monitor:x86_64 .
ARG APP_NAME=adsw_monitor
ENV APP_NAME=${APP_NAME}

# Install GTK, Wayland, OpenGL runtime libraries.
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

# Extract the app bundle (tar.gz → /app/).
WORKDIR /app
ADD output/${APP_NAME}-x86_64-release.tar.gz /app/

# Copy config.json next to the binary (config/ — path #5 in config_loader_io.dart).
COPY ${APP_NAME}/config/config.json /app/config/config.json

# Set executable bit + stable entrypoint name (the exec-form ENTRYPOINT
# does not expand variables, so use a symlink).
RUN chmod +x /app/${APP_NAME} && ln -sf /app/${APP_NAME} /app/entrypoint

# Wayland / X11 environment variables (injected at runtime).
ENV XDG_RUNTIME_DIR=/tmp/runtime
ENV DISPLAY=:0

ENTRYPOINT ["/app/entrypoint"]
