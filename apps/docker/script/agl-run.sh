#!/bin/bash
# AGL flutter-auto 실행 스크립트
set -e

FLUTTER_AUTO=${FLUTTER_AUTO_BIN:-/usr/bin/flutter-auto}
BUNDLE_PATH=${BUNDLE_PATH:-/usr/share/flutter/${APP_NAME}/${APP_VERSION}/release}
APP_ID=${APP_NAME:-adsw_monitor}

if [ ! -f "${FLUTTER_AUTO}" ]; then
    echo "[ERROR] flutter-auto 를 찾을 수 없습니다: ${FLUTTER_AUTO}"
    echo ""
    echo "다음 중 하나로 해결하세요:"
    echo "  1. 호스트에서 볼륨 마운트:"
    echo "     docker run -v /usr/bin/flutter-auto:${FLUTTER_AUTO} ..."
    echo "  2. 환경변수로 경로 지정:"
    echo "     docker run -e FLUTTER_AUTO_BIN=/path/to/flutter-auto ..."
    exit 1
fi

if [ ! -d "${BUNDLE_PATH}" ]; then
    echo "[ERROR] 번들 디렉토리를 찾을 수 없습니다: ${BUNDLE_PATH}"
    exit 1
fi

echo "[INFO] flutter-auto : ${FLUTTER_AUTO}"
echo "[INFO] bundle       : ${BUNDLE_PATH}"
echo "[INFO] app-id       : ${APP_ID}"
echo "[INFO] WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
echo "[INFO] XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"

# ── agl-shell 자기 활성화(풀화면 + 전면) ───────────────────────────────────
# agl-compositor 에서는 **클라이언트가 창 크기를 정하지 못한다** — 서페이스 기하는
# agl-shell 이 소유하고 gRPC(:14005)로만 바뀐다. 실측: flutter-auto 에 -f 를 줘도
# 로그에 `Fullscreen: true` 만 찍히고 화면은 그대로 AGL 홈스크린과 겹쳤다
# (창이 출력 일부만 덮음). 그래서 앱이 스스로 SetAppFullscreen + ActivateApp 을
# 호출해 전체 출력을 차지한다 — rviz2 컨테이너가 cage/homebar 에 쓰는 것과 같은 패턴.
#
# ⚠️ 호출 시점이 중요하다(보드 실측). 서페이스가 매핑되기 **전에** SetAppFullscreen 을
# 부르면 그 앱은 화면에서 아예 사라지고, 이후 activate/normal/fullscreen 을 몇 번
# 불러도 복구되지 않는다(컨테이너 재생성만이 해결). 실측 경계:
#   기동 +2초 → 영구 비표시 ❌   +5초 → 풀화면 ✅   +15초 → 풀화면 ✅
# 그래서 넉넉한 기본 대기(15초)를 두고 Set + Activate 를 **한 번만** 부른다(6/6 성공).
# agl-shell 은 ack 을 주지 않아 성공을 관측할 수 없고, AppStatusState 스트림도
# applaunchd 등록 앱만 보고하므로(실측: 컨테이너 클라이언트는 이벤트 없음) 대기가 최선이다.
#   느린 보드면 대기를 늘린다: -e AGL_SHELL_ACTIVATE_DELAY=25
#   끄기: -e AGL_SHELL_ACTIVATE=0   출력 지정: -e AGL_OUTPUT=DP-1
#
# 단, `--window-type BG` 로 뜨는 경우는 **자기활성화를 하지 않는다**. BG(AGL 배경 롤)는
# 그 자체로 출력 전체를 차지하고 항상 앱 아래에 있어 풀화면 롤·활성화가 불필요하며,
# 풀화면 롤을 주면 앱 위로 올라가 rviz2 가 가려진다(보드 실측). BG 는 AGL 기본
# 홈스크린을 대체하는 구성 — docs/rviz2/board-launcher-fullscreen-guide.md 참고.
WL_SOCK="${XDG_RUNTIME_DIR:-/run/user/1001}/${WAYLAND_DISPLAY:-wayland-0}"
case " $* " in *" BG "*) WINDOW_TYPE_BG=1 ;; *) WINDOW_TYPE_BG=0 ;; esac
if [ "$WINDOW_TYPE_BG" = "1" ]; then
    echo "[INFO] --window-type BG → agl-shell 자기활성화 불필요(배경 롤이 출력 전체 차지)"
elif [ "${AGL_SHELL_ACTIVATE:-1}" = "1" ] && [ -S "${WL_SOCK}" ] \
   && command -v grpcurl >/dev/null 2>&1; then
    (
        S="${AGL_SHELL_GRPC:-127.0.0.1:14005}"
        A=agl_shell_ipc.AglShellManagerService
        O="${AGL_OUTPUT:-DP-1}"
        set_fs()   { grpcurl -plaintext -d "{\"app_id\":\"${APP_ID}\"}" \
                        "$S" "$A"/SetAppFullscreen >/dev/null 2>&1; }
        activate() { grpcurl -plaintext -d "{\"app_id\":\"${APP_ID}\",\"output_name\":\"${O}\"}" \
                        "$S" "$A"/ActivateApp >/dev/null 2>&1; }
        sleep "${AGL_SHELL_ACTIVATE_DELAY:-15}"
        set_fs; sleep 1; activate
        echo "[INFO] agl-shell 풀화면+활성화 (app_id=${APP_ID}, output=${O})"
        # 재확인 호출은 두지 않는다. AGL 홈스크린은 배경(background) 롤이라 활성화를
        # 다투지 않으므로 1회로 충분하고(보드 4/4 성공), 뒤늦은 activate 는 그 사이
        # 사용자가 띄운 rviz2 에서 화면을 도로 빼앗을 수 있다.
    ) &
else
    echo "[INFO] agl-shell 활성화 건너뜀 (wayland 소켓/grpcurl 부재 또는 AGL_SHELL_ACTIVATE=0)"
fi

exec "${FLUTTER_AUTO}" \
    -b "${BUNDLE_PATH}" \
    --xdg-shell-app-id "${APP_ID}" \
    "$@"
