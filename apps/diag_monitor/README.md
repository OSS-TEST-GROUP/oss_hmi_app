# diag_monitor — Diagnostic Monitor

MMF 미들웨어 진단(`diagnosticmgr`) 정보를 보여주는 **읽기 전용 대시보드**
(Diagnostic Monitor, 🩺). rosbridge 로 차량 ROS2 그래프에 접속해 진단 알림 스트림과
진단 항목 목록(PASS/WARNING/FATAL)을 표시한다. 단독 실행 또는 hmi_launcher 에 임베드.

> 원래 `adsw_monitor` 의 **"Diagnostic Info" 탭**이었고, 기능별 앱 분리로 독립 앱이 되었다.
> AD SW(Autoware) 텔레메트리는 [../adsw_monitor](../adsw_monitor) 를 보라.
> 커스텀 ROS 메시지 패키지 `diagnosticmgr/` 도 이 앱으로 함께 이동했다.

- **사용법**: [USAGE.md](USAGE.md)
- **빌드/배포 상세(전 앱 공통, 멀티아치·registry 포함)**: [../docker/docs/DOCKER_GUIDE.md](../docker/docs/DOCKER_GUIDE.md) · 보드 배포: [../../docs/build-install-run-guide.md](../../docs/build-install-run-guide.md)
- **설정(config.json)**: `rosbridge.url`(기본 번들 `ws://172.16.10.48:9090`), `statusTopic`(`/app_status/diag_monitor`). 읽기 경로: `DIAG_CONFIG` → `~/.config/diag_monitor/` → `/etc/diag_monitor/` → 번들 `config/config.json`.

> 아래는 이 앱의 **standalone 빌드·실행·테스트 상세**(dev 환경 셋업, 정적분석, 테스트, arm 빌드, custom ROS 메시지). 요약만 필요하면 위 DOCKER_GUIDE 를 보라.

## Getting Started in x86

### Development Environment Setup

- Start building Flutter Android apps on Linux: https://docs.flutter.dev/get-started/install/linux/android
- Set up Linux development: https://docs.flutter.dev/platform-integration/linux/setup

### How to Run

#### Run rosbridge server

You should run rosbridge server to enable ROS communication.

1. install rosbridge server
```
sudo apt-get update
sudo apt-get install ros-humble-rosbridge-server
```
2. set custom message
```
git clone https://github.com/obigo-gov/oss_hmi_app.git
cd [oss_hmi_app path]/apps/diag_monitor/diagnosticmgr

colcon build --packages-select diagnosticmgr
source install/setup.bash
ros2 interface show diagnosticmgr/msg/DiagnosticInfoResponse #check custom message
```
3. run rosbridge server
```
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

#### Run the 'diag_monitor'

1. flutter run
After moving to the root directory of the 'diag_monitor' project, run the following command.
```
flutter run
```
By defalut, it runs the application in **debug mode**.
If you want to run it in **release mode**, use the following command instead:
```
flutter run --release
```

The executable files for each platform are located in the following paths.
- Android: diag_monitor/build/app/outputs/flutter-apk/
- Linux: diag_monitor/build/linux/x64/{build_mode}/bundle/
<br/>

### How to Run static analysis
In the root directory of the 'diag_monitor' project, run the following command:
```
flutter analyze
```
For more details, please check https://dart.dev/tools/dart-analyze  

<br/>

### How to Run Tests

In the root directory of the 'diag_monitor' project, run the following command:
```
flutter test test/{test_file_name}.dart
```
Before running the **mw_collector_test**,  
you need to generate the mock files using the following command:
```
flutter pub run build_runner build
```
<br/>

### How to create coverage report
In the root directory of the 'diag_monitor' project, run the following command:
```
flutter test --coverage
```
This will generate the **coverage/lcov.info** file. To view it as HTML, run the following command:
```
genhtml coverage/lcov.info -o coverage/html
```
<br/>
<br/>

## How to build for arm
> **권장**: 호스트 SDK 설치 대신 `apps/docker/compose`의 Docker 빌더(`diag_monitor_builder_arm64`, AGL SDK 20.0.3)를 사용하면 자격증명/SDK 설치 없이 원클릭 빌드 가능합니다. 상세: [../docker/docs/DOCKER_GUIDE.md](../docker/docs/DOCKER_GUIDE.md)

### Setting cross compile environment (호스트 직접 빌드 시)
1. install agl-sdk (Make sure AWS CLI is configured via `aws configure`)
```bash
aws s3 cp s3://oss-artifact/yocto-adt/agl/oss-agl-ivi-flutter-aarch64-toolchain-20.0.3.sh .
chmod +x oss-agl-ivi-flutter-aarch64-toolchain-20.0.3.sh
./oss-agl-ivi-flutter-aarch64-toolchain-20.0.3.sh -d /opt/agl-sdk -y
```
2. The build script is included in this repository at `../tools/create_aot_with_yocto_sdk.py`

3. build
```
source {agl sdk path}/environment-setup-aarch64-agl-linux
python3 ../tools/create_aot_with_yocto_sdk.py --app-path={diag monitor app path}
```

### How to build with Docker (recommended)
Run the following commands from the `apps/` directory:

#### Build for arm64 (AGL target)
Uses `Dockerfile.build.arm64` — requires AGL Yocto SDK credentials.

Build the Docker image:
```
docker build \
  --build-arg AGL_SDK_USER=<username> \
  --build-arg AGL_SDK_PASSWORD=<password> \
  -f docker/dockerfile/Dockerfile.build.arm64 \
  -t diag_monitor_builder:arm64 .
```
Run the build (mounts app source and writes output to `./output/`):
```
mkdir -p output
docker run --rm \
  -v $(pwd)/diag_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  diag_monitor_builder:arm64 \
  --app-path=/workspace/app \
  --output-dir=/workspace/output
```
The artifact `diag_monitor-arm64-release.tar.gz` will be created in `./output/`.

Or with docker compose:
```
docker compose -f docker/compose/docker-compose.yml --profile build run --rm diag_monitor_builder_arm64 \
  --app-path=/workspace/app --output-dir=/workspace/output
```

#### Build for x86_64 (Linux desktop)
Uses `Dockerfile.build` — no AGL SDK required.

Build the Docker image:
```
docker build \
  -f docker/dockerfile/Dockerfile.build \
  -t diag_monitor_builder:x86_64 .
```
Run the build:
```
mkdir -p output
docker run --rm \
  -v $(pwd)/diag_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  diag_monitor_builder:x86_64 \
  --app-path=/workspace/app \
  --output-dir=/workspace/output
```
The artifact `diag_monitor-x86_64-release.tar.gz` will be created in `./output/`.

Or with docker compose:
```
docker compose -f docker/compose/docker-compose.yml --profile build run --rm diag_monitor_builder_x86 \
  --app-path=/workspace/app --output-dir=/workspace/output
```

### How to build arm64 runtime Docker image
After the AOT build is complete, run the following commands from the `apps/` directory:

**On arm64 host (AGL target directly):**
```
docker build \
  -f docker/dockerfile/Dockerfile.arm64 \
  -t diag_monitor:arm64 .
```

**On x86_64 host (cross-build, requires buildx + QEMU):**
```
docker buildx create --use
docker buildx build --platform linux/arm64 \
  -f docker/dockerfile/Dockerfile.arm64 \
  -t diag_monitor:arm64 \
  --load .
```

**Run on AGL:**
```
docker run --rm \
  -v /usr/bin/flutter-auto:/usr/bin/flutter-auto \
  -v /run/user/1001:/run/user/1001 \
  -v /dev/dri:/dev/dri \
  -e WAYLAND_DISPLAY=wayland-0 \
  -e XDG_RUNTIME_DIR=/run/user/1001 \
  --network host \
  diag_monitor:arm64
```

Or with docker compose (from `apps/docker/` directory):
```
docker compose -f docker/compose/docker-compose.yml up diag_monitor_arm64
```

### How to run in agl
Transfer the build artifact (diag_monitor-arm64-release.tar.gz) to the AGL environment via **SCP** and extract it.
  
**flutter_auto**
```
export XDG_RUNTIME_DIR=/run/user/1001
/usr/bin/flutter-auto -b [압축파일 푼 위치]/usr/share/flutter/diag_monitor/3.32.2/release --xdg-shell-app-id diag_monitor
```
<br/>

### How to Use custom ROS message

1. build the custom ROS message  
Create custom msg and srv files
- https://docs.ros.org/en/humble/Tutorials/Beginner-Client-Libraries/Custom-ROS2-Interfaces.html
2. source the setup files  
Source the **local_setup.bash** and **package.bash**.
