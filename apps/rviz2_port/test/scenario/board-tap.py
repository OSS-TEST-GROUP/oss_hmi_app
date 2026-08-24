#!/usr/bin/env python3
"""터치 주입 — 실기 검증용.

  tap.py X Y                 좌표 탭 (기존 사용법 그대로)
  tap.py swipe X1 Y1 X2 Y2   드래그 (목록 스크롤 정규화용)

왜 swipe 가 필요한가: lfc_monitor 목록이 뷰포트보다 길어지면(재배포 후 core 가
"Services (no container)" 3종까지 보고) 스크롤이 생기고, Stop 탭 뒤 목록이 밀려
고정 좌표가 버튼 대신 제목을 때린다. 페이지 재진입은 스크롤을 초기화하지 않으므로
(앱이 offset 유지) 아래로 크게 드래그해 최상단으로 되돌린 뒤 탭한다.
"""
import struct, time, sys
DEV = "/dev/input/event1"
EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
SYN_REPORT = 0
BTN_TOUCH = 0x14a
ABS_X, ABS_Y = 0x00, 0x01
ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0x2f, 0x35, 0x36, 0x39
SCREEN_W, SCREEN_H = 1920, 1080
RANGE_X, RANGE_Y = 16383, 9599

def ev(f, t, c, v):
    f.write(struct.pack('@llHHi', 0, 0, t, c, v))

def raw(px, py):
    return int(px / SCREEN_W * RANGE_X), int(py / SCREEN_H * RANGE_Y)

def _down(f, rx, ry):
    ev(f, EV_ABS, ABS_MT_SLOT, 0)
    ev(f, EV_ABS, ABS_MT_TRACKING_ID, 1)
    ev(f, EV_ABS, ABS_MT_POSITION_X, rx)
    ev(f, EV_ABS, ABS_MT_POSITION_Y, ry)
    ev(f, EV_ABS, ABS_X, rx)
    ev(f, EV_ABS, ABS_Y, ry)
    ev(f, EV_KEY, BTN_TOUCH, 1)
    ev(f, EV_SYN, SYN_REPORT, 0)

def _move(f, rx, ry):
    ev(f, EV_ABS, ABS_MT_POSITION_X, rx)
    ev(f, EV_ABS, ABS_MT_POSITION_Y, ry)
    ev(f, EV_ABS, ABS_X, rx)
    ev(f, EV_ABS, ABS_Y, ry)
    ev(f, EV_SYN, SYN_REPORT, 0)

def _up(f):
    ev(f, EV_ABS, ABS_MT_TRACKING_ID, -1)
    ev(f, EV_KEY, BTN_TOUCH, 0)
    ev(f, EV_SYN, SYN_REPORT, 0)

def tap(px, py):
    rx, ry = raw(px, py)
    print(f"  tap px=({px},{py}) → raw=({rx},{ry})")
    with open(DEV, 'wb', buffering=0) as f:
        _down(f, rx, ry)
        time.sleep(0.12)
        _up(f)

def swipe(x1, y1, x2, y2, steps=24, hold=0.012):
    """관성 스크롤이 아니라 '끌기' 로 이동시킨다 (steps 만큼 나눠 move)."""
    print(f"  swipe ({x1},{y1}) → ({x2},{y2})")
    with open(DEV, 'wb', buffering=0) as f:
        rx, ry = raw(x1, y1)
        _down(f, rx, ry)
        time.sleep(0.05)
        for i in range(1, steps + 1):
            cx = x1 + (x2 - x1) * i / steps
            cy = y1 + (y2 - y1) * i / steps
            _move(f, *raw(cx, cy))
            time.sleep(hold)
        time.sleep(0.08)
        _up(f)

if __name__ == "__main__":
    if len(sys.argv) >= 6 and sys.argv[1] == "swipe":
        swipe(*[int(v) for v in sys.argv[2:6]])
    else:
        x = int(sys.argv[1]) if len(sys.argv) > 1 else 1903
        y = int(sys.argv[2]) if len(sys.argv) > 2 else 13
        tap(x, y)
