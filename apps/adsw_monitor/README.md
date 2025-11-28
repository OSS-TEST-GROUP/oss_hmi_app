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

### How to Run static analysis
In the root directory of the 'adsw_monitor' project, run the following command:
```
flutter analyze
```
For more details, please check https://dart.dev/tools/dart-analyze
  
### How to Run Tests

In the root directory of the 'adsw_monitor' project, run the following command:
```
flutter test test/{test_file_name}.dart
```
Before running the **adsw_collector_test** and **mw_collector_test**, you need to generate the mock files using the following command:
```
flutter pub run build_runner build
```
### How to create coverage report
In the root directory of the 'adsw_monitor' project, run the following command:
```
flutter test --coverage
```
This will generate the **coverage/lcov.info** file.
To view it as HTML, run the following command:
```
genhtml coverage/lcov.info -o coverage/html
```

## How to build for arm
### Setting cross compile environment
1. install agl-sdk
```
wget http://172.16.10.216:8081/repository/yocto-adt/agl/oss-agl-ivi-flutter-aarch64-toolchain-19.92.0.sh
```
2. download python script
  
3. build
```
source {agl adk path}/environment-setup-aarch64-agl-linux
cd {python script path}
python3 create_aot_with_yocto_sdk.py --app-path={adsw monitor app path}
```
### How to run in agl
Transfer the build artifact (adsw_monitor-release.tar.gz) to the AGL environment via **SCP** and extract it.
  
**flutter_auto**
```
export XDG_RUNTIME_DIR=/run/user/1001
/usr/bin/flutter-auto -b [압축파일 푼 위치]/usr/share/flutter/adsw_monitor/3.32.2/release --xdg-shell-app-id adsw_monitor
```
**docker**
```
docker pull oss_hmi_container
docker run ~
docker exec oss_hmi_container sh -lc '' # change the bundle file
docker commit ~~
docker run ~~~~
```

### How to Use custom ROS message

1. build the custom ROS message  
Create custom msg and srv files
- https://docs.ros.org/en/humble/Tutorials/Beginner-Client-Libraries/Custom-ROS2-Interfaces.html
2. source the setup files  
Source the **local_setup.bash** and **package.bash**.
