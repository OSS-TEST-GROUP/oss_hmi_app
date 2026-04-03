#!/usr/bin/env python3
"""
adsw_monitor config 편집 툴

config.json을 수정하고, 실행 중인 Docker 컨테이너에 즉시 반영합니다.
앱은 시작 시에만 config를 로딩하므로, 변경 후 컨테이너를 재시작합니다.

사용법:
  python3 tools/config_tool.py show
  python3 tools/config_tool.py set --ros-url ws://192.168.1.10:9090
  python3 tools/config_tool.py set --status-topic /my/topic
  python3 tools/config_tool.py set --ros-url ws://192.168.1.10:9090 --restart
  python3 tools/config_tool.py restart
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

# config.json 경로: tools/ 의 상위(apps/) → adsw_monitor/config/config.json
SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SCRIPT_DIR.parent / "adsw_monitor" / "config" / "config.json"
DEFAULT_CONTAINER = "adsw_monitor"


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        print(f"[error] config.json not found: {CONFIG_PATH}", file=sys.stderr)
        sys.exit(1)
    with open(CONFIG_PATH) as f:
        return json.load(f)


def save_config(cfg: dict) -> None:
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print(f"[saved] {CONFIG_PATH}")


def show_config(cfg: dict) -> None:
    ros_url = cfg.get("rosbridge", {}).get("url", "(not set)")
    status_topic = cfg.get("statusTopic", "(not set)")
    print(f"  rosbridge.url  : {ros_url}")
    print(f"  statusTopic    : {status_topic}")


def container_status(name: str) -> str:
    """running / exited / not found"""
    result = subprocess.run(
        ["docker", "inspect", "--format", "{{.State.Status}}", name],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return "not found"
    return result.stdout.strip()


def restart_container(name: str) -> None:
    status = container_status(name)
    if status == "not found":
        print(f"[warn] container '{name}' not found — skipping restart")
        return
    if status != "running":
        print(f"[warn] container '{name}' is {status} — skipping restart")
        return
    print(f"[restart] container '{name}'...")
    result = subprocess.run(["docker", "restart", name], capture_output=True, text=True)
    if result.returncode == 0:
        print(f"[ok] container '{name}' restarted")
    else:
        print(f"[error] restart failed: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)


def cmd_show(args) -> None:
    cfg = load_config()
    print(f"[config] {CONFIG_PATH}")
    show_config(cfg)
    status = container_status(args.container)
    print(f"  container      : {args.container} ({status})")


def cmd_set(args) -> None:
    cfg = load_config()
    changed = False

    if args.ros_url:
        if not args.ros_url.startswith("ws://") and not args.ros_url.startswith("wss://"):
            print("[error] --ros-url must start with ws:// or wss://", file=sys.stderr)
            sys.exit(1)
        cfg.setdefault("rosbridge", {})["url"] = args.ros_url
        print(f"[set] rosbridge.url = {args.ros_url}")
        changed = True

    if args.status_topic:
        if not args.status_topic.startswith("/"):
            print("[error] --status-topic must start with /", file=sys.stderr)
            sys.exit(1)
        cfg["statusTopic"] = args.status_topic
        print(f"[set] statusTopic = {args.status_topic}")
        changed = True

    if not changed:
        print("[info] nothing to change — use --ros-url or --status-topic")
        return

    save_config(cfg)
    print()
    show_config(cfg)

    if args.restart:
        print()
        restart_container(args.container)


def cmd_restart(args) -> None:
    restart_container(args.container)


def main():
    parser = argparse.ArgumentParser(
        description="adsw_monitor Docker config 편집 툴",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--container", default=DEFAULT_CONTAINER,
        help=f"Docker 컨테이너 이름 (기본: {DEFAULT_CONTAINER})",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # show
    p_show = sub.add_parser("show", help="현재 config 출력")
    p_show.set_defaults(func=cmd_show)

    # set
    p_set = sub.add_parser("set", help="config 값 변경")
    p_set.add_argument("--ros-url", metavar="URL",
                       help="rosbridge WebSocket URL (예: ws://192.168.1.10:9090)")
    p_set.add_argument("--status-topic", metavar="TOPIC",
                       help="ROS2 상태 토픽 (예: /app_status/adsw_monitor)")
    p_set.add_argument("--restart", action="store_true",
                       help="변경 후 컨테이너 재시작")
    p_set.set_defaults(func=cmd_set)

    # restart
    p_restart = sub.add_parser("restart", help="컨테이너 재시작")
    p_restart.set_defaults(func=cmd_restart)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
