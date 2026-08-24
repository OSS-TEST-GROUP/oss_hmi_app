# Orin 보드 화면 방향(가로/세로) 설정 가이드

AGL 보드의 화면 방향은 컴포지터 설정 `/etc/xdg/weston/weston.ini` 의 `[output] transform`
한 줄로 결정된다. 보드를 재플래싱하면 이미지에 들어 있는 값으로 **되돌아간다**.

관련 문서: [시나리오 테스트 가이드](scenario-test-guide.md) · [통합 테스트 절차서](../../../oss_multisw_framework/docs/guide/integration-test-procedure-guide.md)

---

## 1. 증상 — 화면이 세로로 보인다

- 보드 화면 캡처의 글자가 **세로로 누워** 보이고, 런처 타일이 좌측에 세로로 쌓인다.
- 자동화(터치 주입) 좌표가 전부 빗나간다 — 가로 기준으로 잡아 둔 좌표가 맞지 않는다.

## 2. 사실 확인 (원인 특정)

```bash
ssh root@<board>
# ① 현재 설정
grep -A3 '\[output\]' /etc/xdg/weston/weston.ini
# ② 이 파일을 제공한 패키지 (= 이미지에서 온 것인지)
rpm -qf /etc/xdg/weston/weston.ini
# ③ 패널의 물리 해상도 (가로 패널인지)
for f in /sys/class/drm/*/status; do d=$(dirname $f); \
  echo "$(basename $d): $(cat $f) $(head -1 $d/modes 2>/dev/null)"; done
```

2026-08-06 보드 실측:

```
[output]
name=DP-1
transform=rotate-90          ← 세로 회전의 원인
제공 패키지 : weston-ini-conf-1.0-r0
패널        : card0-DP-1 connected 1920x1080   ← 물리적으로 가로
drop-in     : /etc/xdg/weston/weston.ini.d 없음 (빌드 시 단일 파일로 합성)
OS          : AGL 20.0.3 (trout)
```

즉 **패널은 가로인데 이미지가 90° 회전을 넣어** 세로로 뜨고 있었다.

## 3. 방법 1 — 런타임에 가로로 전환 (즉시, 재플래싱 시 사라짐)

```bash
ssh root@<board>
cp /etc/xdg/weston/weston.ini /etc/xdg/weston/weston.ini.bak   # 되돌릴 수 있게
sed -i 's/^transform=rotate-90/transform=normal/' /etc/xdg/weston/weston.ini
grep -A3 '\[output\]' /etc/xdg/weston/weston.ini               # 확인

systemctl restart agl-compositor    # 컴포지터 재시작 (또는 reboot)
```

`transform=normal` 대신 그 줄을 **삭제**해도 기본이 가로다. 값은 `normal` / `rotate-90` /
`rotate-180` / `rotate-270` / `flipped*` 를 쓸 수 있다.

### 3.1 컴포지터 재시작 후 반드시 다시 띄울 것

컴포지터를 재시작하면 wayland 소켓이 새로 생기고 **기존 클라이언트가 모두 끊긴다**.
순서대로 되살린다:

```bash
# ① HMI 스택 — ext-agl 이 런처를 자동 기동한다
cd /root/oss
docker compose -f docker-compose-integration.yaml \
               -f docker-compose-agl-board.override.yaml \
               --env-file .env.integration up -d --force-recreate mmf-ext-agl
# ② rviz2 — 컨테이너는 HMI 의 rviz2_panel 이 관리한다. 패널에서 Start 를 누른다
#    (컴포지터가 바뀌었으므로 이전 rviz2 컨테이너는 정지/삭제 후 새로 띄운다)
docker stop rviz2 2>/dev/null; docker rm rviz2 2>/dev/null
```

### 3.2 검증

```bash
# 캡처해서 글자가 가로로 읽히는지 본다
bash /root/shot.sh && ls -l /root/shot.png
# 컴포지터가 인식한 출력 상태
weston-info 2>/dev/null | grep -iE 'transform|width|height'
# rviz2 가 cage 경로로 떴는지 (보드 정상 경로)
docker logs rviz2 2>&1 | grep -E 'cage \+ rviz2 시작|homebar'
```

### 3.3 되돌리기 (세로로)

```bash
cp /etc/xdg/weston/weston.ini.bak /etc/xdg/weston/weston.ini   # 또는
sed -i 's/^transform=normal/transform=rotate-90/' /etc/xdg/weston/weston.ini
systemctl restart agl-compositor
```

## 4. 방법 2 — 이미지 플래싱부터 가로로 (영구)

`weston.ini` 는 meta-agl 의 **`weston-ini-conf`** 레시피가 빌드 시 합성한다. 우리 레이어에
bbappend 를 얹어 산출물의 transform 을 고정하면 플래싱된 이미지가 처음부터 가로다.

`meta-<our-layer>/recipes-graphics/wayland/weston-ini-conf_%.bbappend`:

```bitbake
# DP-1 패널은 물리적으로 가로(1920x1080)다. AGL 기본 이미지가 rotate-90 을 넣어 세로로
# 뜨므로 이미지 빌드 시점에 가로로 고정한다. weston.ini 는 빌드 때 단일 파일로 합성되고
# 런타임 drop-in(weston.ini.d)이 없어, **결과 파일을 후처리**한다 — 업스트림이 조립
# 방식을 바꿔도 깨지지 않는다.
WESTON_OUTPUT_TRANSFORM ?= "normal"

do_install:append() {
    f="${D}${sysconfdir}/xdg/weston/weston.ini"
    if grep -q '^transform=' "$f"; then
        sed -i "s/^transform=.*/transform=${WESTON_OUTPUT_TRANSFORM}/" "$f"
    else
        sed -i "/^\[output\]/a transform=${WESTON_OUTPUT_TRANSFORM}" "$f"
    fi
}
```

머신마다 다르게 하려면 `conf/machine/<machine>.conf` 에서
`WESTON_OUTPUT_TRANSFORM = "rotate-90"` 처럼 덮어쓴다.

빌드·검증(AGL 빌드 호스트에서):

```bash
bitbake -e weston-ini-conf | grep -E '^SRC_URI=|^FILESEXTRAPATHS'   # 조립 방식 확인
bitbake weston-ini-conf
grep -A3 '\[output\]' tmp/work/*/weston-ini-conf/*/image/etc/xdg/weston/weston.ini
bitbake <image-recipe>        # 플래싱 이미지 재생성
```

플래싱 후 보드에서 `grep -A3 '\[output\]' /etc/xdg/weston/weston.ini` 로 `normal` 확인.

## 5. 자동화(터치 주입) 좌표와의 관계

**입력은 출력과 같은 회전 좌표계를 쓴다** — 컴포지터가 터치도 함께 회전시킨다(실측
2026-08-06: 회전 상태에서 캡처에 보이는 픽셀 위치로 탭하니 정확히 눌렸다).

| 화면 방향 | 탭 좌표 기준 |
|---|---|
| 가로(`normal`) | `scenario-test-guide.md` 의 좌표표 그대로 사용 |
| 세로(`rotate-90`) | 좌표표가 **맞지 않는다**. 캡처(`shot.sh`)에 보이는 픽셀 위치로 다시 측정해 사용 |

시나리오 하네스(`apps/rviz2_port/test/scenario/board_scenario.sh`)의 좌표는 **가로 기준**이다.
보드를 세로로 쓸 거라면 하네스에 좌표 변환을 넣어야 하고, 가로로 맞추면 하네스는 수정 없이
그대로 동작한다.
