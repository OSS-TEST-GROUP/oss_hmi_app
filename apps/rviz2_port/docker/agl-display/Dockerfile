# rviz2-agl — Orin AGX AGL 디스플레이용 rviz2 컨테이너 (ADR-0018, F100)
#
# 구조: cage(wlroots 키오스크, wayland 클라이언트 + XWayland 내장) 위에서
# rviz2(X11/Qt5/OGRE) 실행. 호스트(AGL)는 agl-compositor 소켓만 공유 (이미지 불변).
#
# cage 채택 이유 (weston 9 대비, 실측):
#  - weston 9 는 xdg_toplevel set_app_id 를 호출하지 않아 agl-compositor 가
#    활성화 불가 (agl-shell 은 app_id 기반). cage(wlroots)는 app_id="wlroots" 설정.
#  - 단일 앱 풀스크린 키오스크 — rviz2 용도에 정확히 부합, 데스크톱 크롬 없음.
#  - root 실행 거부 → 반드시 --user 1001(agl-driver와 동일 uid)로 실행.
#
# 빌드 (보드 또는 arm64 호스트):   docker build -t rviz2-agl .
# x86 PC 에서 빌드 시:             docker buildx build --platform linux/arm64 -t rviz2-agl .
FROM ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive

# rviz2 (rviz-ogre-vendor 의 libOgreMain 포함) + cage/xwayland + SW GL(llvmpipe)
# RMW: ros:humble 기본 = rmw_fastrtps_cpp. cyclonedds 도 함께 설치해 Autoware 의
# RMW 에 맞춰 -e RMW_IMPLEMENTATION 으로 전환 가능하게 한다.
# ⚠️ 크로스보드 DDS 는 **양쪽 RMW 가 동일해야** discovery 자체가 성립한다(다르면 토픽이
#    전혀 안 보임). 현행 Autoware(151)=fastrtps 기본 → 미설정 시 자동 일치.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-humble-rviz2 \
        ros-humble-rviz-default-plugins \
        ros-humble-rmw-cyclonedds-cpp \
        ros-humble-rmw-fastrtps-cpp \
        cage \
        xwayland \
        libgl1-mesa-dri \
        mesa-utils \
        dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# 호스트 agl-driver(uid 1001)와 동일 uid — wayland 소켓/XDG_RUNTIME_DIR 권한 정합
RUN useradd -m -u 1001 -U agl

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# XDG_RUNTIME_DIR 은 run-on-board.sh 가 호스트 소켓 디렉토리를 마운트하며 지정
ENTRYPOINT ["/entrypoint.sh"]
