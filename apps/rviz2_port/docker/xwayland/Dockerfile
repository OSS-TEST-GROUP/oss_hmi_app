# RViz2 (ROS2 Humble) + XWayland + Weston (Phase 1-B)
# Base: rviz_agl:x11 (from R002) + Weston compositor + XWayland
FROM rviz_agl:x11 AS xwayland

ENV DEBIAN_FRONTEND=noninteractive

# ── Install Weston + XWayland ──────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Wayland compositor (Ubuntu 22.04 uses libweston-9)
    weston \
    libweston-9-0 \
    # XWayland server (X11 apps on Wayland)
    xwayland \
    # X11 utilities for XWayland
    xauth \
    xkb-data \
    x11-xserver-utils \
    # Optional: VNC for remote GUI access (debugging)
    x11vnc \
    && rm -rf /var/lib/apt/lists/*

# ── Environment variables for Weston + XWayland ────────────────────────────────
ENV XDG_RUNTIME_DIR=/run/user/1000
ENV WAYLAND_DISPLAY=wayland-0
ENV DISPLAY=:0
ENV QT_QPA_PLATFORM=xcb

# Create runtime directory for Wayland socket and X11 Unix socket
RUN mkdir -p ${XDG_RUNTIME_DIR} && chmod 700 ${XDG_RUNTIME_DIR} && \
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# ── Weston configuration (headless backend) ────────────────────────────────────
RUN mkdir -p /root/.config
COPY docker/xwayland/weston.ini /root/.config/weston.ini

# ── Custom entrypoint for Weston + XWayland + RViz2 ────────────────────────────
COPY docker/xwayland/entrypoint-xwayland.sh /entrypoint-xwayland.sh
RUN chmod +x /entrypoint-xwayland.sh

ENTRYPOINT ["/entrypoint-xwayland.sh"]
CMD []
