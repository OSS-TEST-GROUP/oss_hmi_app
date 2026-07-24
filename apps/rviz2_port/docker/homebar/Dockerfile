# homebar — floating "home" button overlay container (F010).
#
# A plain xdg_toplevel Wayland app (app_id "homebar") that draws a home button.
# The launcher script shows+floats it on top via agl-shell-activator, and on
# tap it calls the agl-shell gRPC (127.0.0.1:14005) ActivateApp("hmi_launcher")
# via grpcurl to return to the launcher.
#
# Why not an agl-shell panel? Both shell-client slots are taken (grpc-server =
# agl_shell, flutter-auto = agl_shell_ext), so a 3rd shell client is rejected.
# A normal floated app avoids that entirely.
#
#   docker build -t homebar:latest .
#   docker run -d --name homebar --net=host --user 1001:1001 \
#     -v /run/user/1001:/host-xdg -e XDG_RUNTIME_DIR=/host-xdg \
#     -e WAYLAND_DISPLAY=wayland-0 homebar:latest
#   agl-shell-activator -a activate -p homebar -o DP-1
#   agl-shell-activator -a float    -p homebar -o DP-1
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc libc6-dev libwayland-dev libwayland-bin wayland-protocols pkg-config \
        ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

# grpcurl (static arm64) — used at runtime for the return-to-launcher RPC.
ARG GRPCURL_VER=1.9.1
RUN wget -qO /tmp/g.tgz \
      "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VER}/grpcurl_${GRPCURL_VER}_linux_arm64.tar.gz" \
 && tar -xzf /tmp/g.tgz -C /usr/local/bin grpcurl \
 && rm /tmp/g.tgz && chmod +x /usr/local/bin/grpcurl

WORKDIR /src
COPY homebar.c ./
COPY agl_shell.proto /opt/agl_shell.proto

# Generate xdg-shell client stubs, compile, drop build artifacts.
RUN XDG=/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
 && wayland-scanner private-code  "$XDG" xdg-shell-protocol.c \
 && wayland-scanner client-header "$XDG" xdg-shell-client-protocol.h \
 && gcc -O2 -Wall homebar.c xdg-shell-protocol.c -o /usr/local/bin/homebar \
        $(pkg-config --cflags --libs wayland-client) \
 && rm -f xdg-shell-protocol.c xdg-shell-client-protocol.h

RUN useradd -m -u 1001 -U agl
USER agl
ENTRYPOINT ["/usr/local/bin/homebar"]
