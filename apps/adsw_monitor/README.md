# adsw_monitor

A new Flutter project for AD SW monitoring.

## Getting Started

### Development Environment Setup

- Start building Flutter Android apps on Linux: https://docs.flutter.dev/get-started/install/linux/android
- Set up Linux development: https://docs.flutter.dev/platform-integration/linux/setup

### How to Run

#### Run rosbridge server

You should run rosbridge server to enable ROS communication.

1. install rosbridge server
```
sudo apt-get install ros-humble-rosbridge-server
```
2. run rosbridge server
```
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

#### Run the 'adsw_monitor'

1. git clone
```
git clone https://lotte-autops.com/oss_group1/oss_hmi_app.git
```
2. flutter run
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

### How to Run Tests

In the root directory of the 'adsw_monitor' project, run the following command.
```
flutter test test/{test_file_name}.dart
```

### How to Use custom ROS message

1. build the custom ROS message  
Create custom msg and srv files
- https://docs.ros.org/en/humble/Tutorials/Beginner-Client-Libraries/Custom-ROS2-Interfaces.html
2. copy/move the build outputs  
Use the following command to move the build output directory to the ROS shared library directory.
```
cp -r install/{package_name}/share/{package_name} /opt/ros/humble/share
```
3. source the setup files  
Source the **local_setup.bash** and **package.bash** located in the directory moved in step 2.