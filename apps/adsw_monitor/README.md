# adsw_monitor

A new Flutter project for AD SW monitoring.

<img width="500" height="819" alt="Screenshot from 2025-10-27 10-20-22" src="https://github.com/user-attachments/assets/524a9f69-132c-4b01-8c2d-2539ef586cb8" />
<img width="500" height="819" alt="Screenshot from 2025-10-27 10-22-14" src="https://github.com/user-attachments/assets/811d299c-98fd-438c-8b47-f05131d440fb" />


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
cd [oss_hmi_app path]/apps/adsw_monitor/diagnosticmgr

colcon build --packages-select diagnosticmgr
source install/setup.bash
ros2 interface show diagnosticmgr/msg/DiagnosticInfoResponse #check custom message
```
3. run rosbridge server
```
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

#### Run the 'adsw_monitor'

1. flutter run
After moving to the root directory of the 'adsw_monitor' project, run the following command.
```
flutter run
```
By defalut, it runs the application in **debug mode**.
If you want to run it in **release mode**, use the following command instead:
```
flutter run --release
```

The executable files for each platform are located in the following paths.
- Android: adsw_monitor/build/app/outputs/flutter-apk/
- Linux: adsw_monitor/build/linux/x64/{build_mode}/bundle/
<br/>

### How to Run static analysis
In the root directory of the 'adsw_monitor' project, run the following command:
```
flutter analyze
```
For more details, please check https://dart.dev/tools/dart-analyze  

<br/>

### How to Run Tests

In the root directory of the 'adsw_monitor' project, run the following command:
```
flutter test test/{test_file_name}.dart
```
Before running the **adsw_collector_test** and **mw_collector_test**,  
you need to generate the mock files using the following command:
```
flutter pub run build_runner build
```
<br/>

### How to create coverage report
In the root directory of the 'adsw_monitor' project, run the following command:
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
### Setting cross compile environment
1. install agl-sdk
```
wget --user=ossdev --password=ossdev1234 \
  https://repo.obigo.com/repository/yocto-adt/agl/oss-agl-ivi-flutter-aarch64-toolchain-19.92.0.sh
chmod +x oss-agl-ivi-flutter-aarch64-toolchain-19.92.0.sh
./oss-agl-ivi-flutter-aarch64-toolchain-19.92.0.sh -d /opt/agl-sdk -y
```
2. The build script is included in this repository at `../tools/create_aot_with_yocto_sdk.py`

3. build
```
source {agl sdk path}/environment-setup-aarch64-agl-linux
python3 ../tools/create_aot_with_yocto_sdk.py --app-path={adsw monitor app path}
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
  -t adsw_monitor_builder:arm64 .
```
Run the build (mounts app source and writes output to `./output/`):
```
mkdir -p output
docker run --rm \
  -v $(pwd)/adsw_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  adsw_monitor_builder:arm64 \
  --app-path=/workspace/app \
  --output-dir=/workspace/output
```
The artifact `adsw_monitor-arm64-release.tar.gz` will be created in `./output/`.

Or with docker compose:
```
docker compose -f docker/compose/docker-compose.yml --profile build run --rm adsw_monitor_builder_arm64 \
  --app-path=/workspace/app --output-dir=/workspace/output
```

#### Build for x86_64 (Linux desktop)
Uses `Dockerfile.build` — no AGL SDK required.

Build the Docker image:
```
docker build \
  -f docker/dockerfile/Dockerfile.build \
  -t adsw_monitor_builder:x86_64 .
```
Run the build:
```
mkdir -p output
docker run --rm \
  -v $(pwd)/adsw_monitor:/workspace/app \
  -v $(pwd)/output:/workspace/output \
  adsw_monitor_builder:x86_64 \
  --app-path=/workspace/app \
  --output-dir=/workspace/output
```
The artifact `adsw_monitor-x86_64-release.tar.gz` will be created in `./output/`.

Or with docker compose:
```
docker compose -f docker/compose/docker-compose.yml --profile build run --rm adsw_monitor_builder_x86 \
  --app-path=/workspace/app --output-dir=/workspace/output
```

### How to build arm64 runtime Docker image
After the AOT build is complete, run the following commands from the `apps/` directory:

**On arm64 host (AGL target directly):**
```
docker build \
  -f docker/dockerfile/Dockerfile.arm64 \
  -t adsw_monitor:arm64 .
```

**On x86_64 host (cross-build, requires buildx + QEMU):**
```
docker buildx create --use
docker buildx build --platform linux/arm64 \
  -f docker/dockerfile/Dockerfile.arm64 \
  -t adsw_monitor:arm64 \
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
  adsw_monitor:arm64
```

Or with docker compose (from `apps/docker/` directory):
```
docker compose -f docker/compose/docker-compose.yml up adsw_monitor_arm64
```

### How to run in agl
Transfer the build artifact (adsw_monitor-arm64-release.tar.gz) to the AGL environment via **SCP** and extract it.
  
**flutter_auto**
```
export XDG_RUNTIME_DIR=/run/user/1001
/usr/bin/flutter-auto -b [압축파일 푼 위치]/usr/share/flutter/adsw_monitor/3.32.2/release --xdg-shell-app-id adsw_monitor
```
<br/>

### How to Use custom ROS message

1. build the custom ROS message  
Create custom msg and srv files
- https://docs.ros.org/en/humble/Tutorials/Beginner-Client-Libraries/Custom-ROS2-Interfaces.html
2. source the setup files  
Source the **local_setup.bash** and **package.bash**.
