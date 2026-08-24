# X11 입력 주입 + 창 제어 + 캡처 도구. 호스트에 xdotool 이 없고 시스템 패키지 설치는
# 승인 대상이므로, 도구를 컨테이너에 담아 호스트 X 소켓에만 붙인다.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        xdotool wmctrl x11-utils imagemagick \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/bin/bash","-lc"]
