#!/usr/bin/env python3
"""OTA Manager mock — ROS2 rclpy node for real-stack integration tests (F013).

This node replaces the Dart MockOtaManager when the Flutter app talks to a
real rosbridge_server (which in turn speaks DDS). It subscribes to the four
request topics and publishes matching responses using the same payload
shape that lib/controller/ota_collector.dart expects.

Run order
---------
    # shell 1 — infra
    ros2 run rosbridge_server rosbridge_websocket   # listens on ws://localhost:9090
    python3 integration_test/ota_manager_mock.py

    # shell 2 — flutter
    DISPLAY=:99 flutter test \\
        integration_test/ota_integration_test.dart \\
        -d linux \\
        --dart-define=OTA_ROS_URL=ws://localhost:9090

Requirements
------------
* ROS2 (tested mental model: Humble / Jazzy)
* Python `rclpy` (`pip install rclpy` or sourced from /opt/ros/<distro>/setup.bash)
* `mmf_interfaces` package providing the message types below. The exact
  field names are derived from ota_data.dart + ota_collector.dart — double
  check against the real .msg files before relying on a green run.

Status
------
SKELETON. Not executed in-repo because mmf_interfaces + ROS2 runtime are
not present in the dev environment. Syntax-validated with py_compile only.
Expected follow-up work:
  1. Vendor-locate the exact mmf_interfaces .msg definitions and fix the
     `import` block if field names differ.
  2. Run under the same ROS_DOMAIN_ID as the production OtaManager.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field
from typing import Dict

try:
    import rclpy
    from rclpy.node import Node
    from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
except ImportError as exc:  # pragma: no cover — handled at runtime
    print(
        "[ota_manager_mock] rclpy is not available. Source your ROS2 "
        "setup.bash (e.g. `source /opt/ros/humble/setup.bash`) before "
        "running this script.",
        file=sys.stderr,
    )
    raise

# mmf_interfaces message types — verify these imports against the real
# package. Field names used below are the best-guess mapping from
# lib/data/ota_data.dart + lib/controller/ota_collector.dart.
try:
    from mmf_interfaces.msg import (  # type: ignore[import-not-found]
        GetAppUpdateSettings,
        GetAppUpdateSettingsResponse,
        SetAppUpdateSettings,
        SetAppUpdateSettingsResponse,
        GetAppUpdateState,
        GetAppUpdateStateResponse,
        SetAppUpdate,
        SetAppUpdateResponse,
        NotifyAppUpdateStatus,
    )
except ImportError as exc:  # pragma: no cover
    print(
        "[ota_manager_mock] mmf_interfaces is not on the Python path. "
        "Build the ROS2 workspace that provides it and source install/setup.bash.",
        file=sys.stderr,
    )
    raise


# ── Seed data (mirrors integration_test/mock_ota_manager.dart) ────────────


@dataclass
class AppRecord:
    name: str
    status: str
    settings: str  # JSON blob the client parses
    state: str


INITIAL_APPS: Dict[str, AppRecord] = {
    "NavigationApp": AppRecord(
        name="NavigationApp",
        status="Synced",
        settings='{"auto_update":true,"interval":3600}',
        state="idle",
    ),
    "MapUpdater": AppRecord(
        name="MapUpdater",
        status="idle",
        settings='{"schedule":"daily","max_size_mb":500}',
        state="ready",
    ),
    "SensorFusion": AppRecord(
        name="SensorFusion",
        status="Unknown",
        settings="{}",
        state="standby",
    ),
}


# ── Topic constants — mirror of lib/data/ota_data.dart ────────────────────

GET_SETTINGS_REQ = "/mmf/otamanager/otaactor_service/GetAppUpdateSettings"
GET_SETTINGS_RESP = "/mmf/otamanager/otaactor_service/GetAppUpdateSettingsResponse"
SET_SETTINGS_REQ = "/mmf/otamanager/otaactor_service/SetAppUpdateSettings"
SET_SETTINGS_RESP = "/mmf/otamanager/otaactor_service/SetAppUpdateSettingsResponse"
GET_STATE_REQ = "/mmf/otamanager/otaactor_service/GetAppUpdateState"
GET_STATE_RESP = "/mmf/otamanager/otaactor_service/GetAppUpdateStateResponse"
SET_UPDATE_REQ = "/mmf/otamanager/otaactor_service/SetAppUpdate"
SET_UPDATE_RESP = "/mmf/otamanager/otaactor_service/SetAppUpdateResponse"
NOTIFY_STATUS = "/mmf/otamanager/otaclient_service/NotifyAppUpdateStatus"


# ── Node ──────────────────────────────────────────────────────────────────


class OtaManagerMock(Node):
    def __init__(self) -> None:
        super().__init__("ota_manager_mock")
        self._apps: Dict[str, AppRecord] = dict(INITIAL_APPS)

        qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )

        # Subscribers (request side)
        self.create_subscription(
            GetAppUpdateSettings, GET_SETTINGS_REQ, self._on_get_settings, qos
        )
        self.create_subscription(
            SetAppUpdateSettings, SET_SETTINGS_REQ, self._on_set_settings, qos
        )
        self.create_subscription(
            GetAppUpdateState, GET_STATE_REQ, self._on_get_state, qos
        )
        self.create_subscription(
            SetAppUpdate, SET_UPDATE_REQ, self._on_set_update, qos
        )

        # Publishers (response side)
        self._get_settings_pub = self.create_publisher(
            GetAppUpdateSettingsResponse, GET_SETTINGS_RESP, qos
        )
        self._set_settings_pub = self.create_publisher(
            SetAppUpdateSettingsResponse, SET_SETTINGS_RESP, qos
        )
        self._get_state_pub = self.create_publisher(
            GetAppUpdateStateResponse, GET_STATE_RESP, qos
        )
        self._set_update_pub = self.create_publisher(
            SetAppUpdateResponse, SET_UPDATE_RESP, qos
        )
        self._notify_pub = self.create_publisher(NotifyAppUpdateStatus, NOTIFY_STATUS, qos)

        # Seed status on startup so clients see all three apps appear.
        self.create_timer(0.5, self._seed_status_once)
        self._seeded = False

        self.get_logger().info(
            "ota_manager_mock ready — %d seeded apps" % len(self._apps)
        )

    # ── Handlers ──────────────────────────────────────────────────────────

    def _on_get_settings(self, req: GetAppUpdateSettings) -> None:
        resp = GetAppUpdateSettingsResponse()
        resp.id = req.id                       # F003: echo request id
        resp.app_name = req.app_name
        app = self._apps.get(req.app_name)
        resp.app_settings = app.settings if app else "{}"
        resp.ret_code = 1 if app else 2
        self._get_settings_pub.publish(resp)

    def _on_set_settings(self, req: SetAppUpdateSettings) -> None:
        app = self._apps.get(req.app_name)
        if app is not None:
            app.settings = req.app_settings
        resp = SetAppUpdateSettingsResponse()
        resp.id = req.id
        resp.app_name = req.app_name
        resp.ret_code = 1 if app else 2
        self._set_settings_pub.publish(resp)

    def _on_get_state(self, req: GetAppUpdateState) -> None:
        resp = GetAppUpdateStateResponse()
        resp.id = req.id
        resp.app_name = req.app_name
        app = self._apps.get(req.app_name)
        resp.app_state_info = app.state if app else "unknown"
        resp.ret_code = 1 if app else 2
        self._get_state_pub.publish(resp)

    def _on_set_update(self, req: SetAppUpdate) -> None:
        # 1) Immediate acceptance.
        resp = SetAppUpdateResponse()
        resp.id = req.id
        resp.app_name = req.app_name
        resp.ret_code = 1
        self._set_update_pub.publish(resp)

        # 2) Progress + completion, matching the Dart mock's 150ms/350ms schedule.
        self.create_timer(
            0.15, lambda name=req.app_name: self._notify_status(name, "updating")
        )
        self.create_timer(
            0.35, lambda name=req.app_name: self._notify_status(name, "complete")
        )

    # ── Helpers ───────────────────────────────────────────────────────────

    def _notify_status(self, app_name: str, status: str) -> None:
        msg = NotifyAppUpdateStatus()
        msg.app_name = app_name
        msg.status = status
        self._notify_pub.publish(msg)

    def _seed_status_once(self) -> None:
        if self._seeded:
            return
        self._seeded = True
        for app in self._apps.values():
            self._notify_status(app.name, app.status)


# ── Entry point ───────────────────────────────────────────────────────────


def main() -> None:
    ap = argparse.ArgumentParser(description="OTA Manager mock (rclpy)")
    ap.add_argument(
        "--add-app",
        action="append",
        default=[],
        metavar="NAME",
        help="Extra app to seed (can be repeated). Defaults to the 3 builtins.",
    )
    args = ap.parse_args()

    rclpy.init()
    node = OtaManagerMock()
    for extra in args.add_app:
        node._apps[extra] = AppRecord(
            name=extra, status="Unknown", settings="{}", state="standby"
        )
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
