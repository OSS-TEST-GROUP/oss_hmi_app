# 시나리오 테스트 하네스

절차·판정 기준·좌표·함정은 **[docs/rviz2/scenario-test-guide.md](../../../../docs/rviz2/scenario-test-guide.md)** 에 있다.
이 디렉토리는 그 가이드가 참조하는 실행 파일 모음이다.

| 파일 | 용도 |
|---|---|
| `board_scenario.sh` | Orin 보드(arm64/AGL) 무한 반복 시나리오 |
| `pc_scenario.sh` | x86 개발 PC(amd64, 호스트 X11) 무한 반복 시나리오 |
| `board-tap.py` | 보드 터치 주입(`/dev/input`, tap/swipe) — 보드 `/root/tap.py` 로 복사 |
| `board-shot.sh` | 보드 화면 캡처(weston-screenshooter) — 보드 `/root/shot.sh` 로 복사 |
| `xtool.Dockerfile` | PC 입력·창제어·캡처 도구(xdotool/wmctrl/imagemagick) 컨테이너 |
| `agl-service-list.x86.pc.yaml` | PC ext-agl 서비스 목록(런처를 X11 인자로 기동) |
| `rviz2_panel.x86.json` | rviz2_panel 설정 — amd64 X11 용 image/dockerRunArgs |
| `hmi_launcher.config.json` | 런처 XDG config — rosbridge URL(151) |
| `hmi_launcher.app_visibility.json` | `rviz2_panel` 타일 표시(기본 숨김 해제) |

## SSH 설정 (자격증명은 저장소에 넣지 않는다)

두 스크립트는 보드/151 에 ssh 로 붙는다. **키 인증을 권장**한다:

```bash
ssh-copy-id root@<board>        # 이후 스크립트가 암호 없이 동작
ssh-copy-id <user>@172.16.10.151
```

암호 인증을 써야 하면 스크립트가 참조하는 `askpass-81.sh` / `askpass-151.sh` 를
**스크립트와 같은 디렉토리에 직접 만든다**(내용은 `echo '<암호>'` 한 줄, `chmod 700`).
이 두 파일은 자격증명이므로 **커밋하지 않는다**(.gitignore 등록됨).
