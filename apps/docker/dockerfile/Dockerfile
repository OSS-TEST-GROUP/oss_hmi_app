# ── docker CLI (static binary, x86_64) ─────────────────────────────────────
# rviz2_monitor (running inside this image) directly controls the host rviz2
# container via the docker CLI.  We download only the static `docker` binary
# from the official download site; no daemon, no docker-compose.
# The docker.sock is bind-mounted at runtime by adsw_manager/agl-service-list.
#
# To update: change DOCKER_CLI_VERSION and rebuild.
FROM ubuntu:22.04 AS docker-cli-fetch
ARG DOCKER_CLI_VERSION=27.5.1
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL \
      "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
      -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz --strip-components=1 -C /usr/local/bin docker/docker \
    && rm /tmp/docker.tgz \
    && chmod +x /usr/local/bin/docker
# ── end docker CLI stage ────────────────────────────────────────────────────

FROM ubuntu:22.04

# Reusable runtime image. To use this Dockerfile for another Flutter app,
# invoke it with --build-arg APP_NAME=<pubspec name>.
#
# Example:
#   docker build -f docker/Dockerfile --build-arg APP_NAME=ota_monitor \
#                -t ota_monitor:x86_64 .
ARG APP_NAME=adsw_monitor
ARG CONFIG_FILE=config.json
ENV APP_NAME=${APP_NAME}
ENV CONFIG_FILE=${CONFIG_FILE}

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

# Copy config next to the binary (config/ — path #5 in config_loader_io.dart).
# CONFIG_FILE defaults to config.json for adsw / ota; hmi_launcher passes
# launcher_config.json.
COPY ${APP_NAME}/config/${CONFIG_FILE} /app/config/${CONFIG_FILE}

# Plugin manifests: hmi_launcher scans HMI_APPS_ROOT for <app>/manifest.json
# to populate its app grid (adsw / lfc / ota). Without these the launcher
# finds no plugins and shows an empty grid. Mirrors Dockerfile.arm64
# (lines 41,84-88). OTA Monitor ships default-disabled via the launcher's
# AppVisibilityStore.kDefaultDisabled, so no manifest change is needed for that.
ENV HMI_APPS_ROOT=/apps
RUN mkdir -p /apps/ota_monitor /apps/adsw_monitor /apps/lfc_monitor /apps/rviz2_monitor
COPY ota_monitor/manifest.json /apps/ota_monitor/manifest.json
COPY adsw_monitor/manifest.json /apps/adsw_monitor/manifest.json
COPY lfc_monitor/manifest.json /apps/lfc_monitor/manifest.json
COPY rviz2_monitor/manifest.json /apps/rviz2_monitor/manifest.json

# Set executable bit + stable entrypoint name (the exec-form ENTRYPOINT
# does not expand variables, so use a symlink).
RUN chmod +x /app/${APP_NAME} && ln -sf /app/${APP_NAME} /app/entrypoint

# Wayland / X11 environment variables (injected at runtime).
ENV XDG_RUNTIME_DIR=/tmp/runtime
ENV DISPLAY=:0

ENTRYPOINT ["/app/entrypoint"]

# Copy the static docker CLI from the fetch stage.
# Used by rviz2_monitor to control the host rviz2 container.
# docker.sock must be bind-mounted at runtime: -v /var/run/docker.sock:/var/run/docker.sock
COPY --from=docker-cli-fetch /usr/local/bin/docker /usr/local/bin/docker
