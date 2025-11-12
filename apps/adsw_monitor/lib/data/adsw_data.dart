List<String> topicList = [
  // vehicle
  '/api/vehicle/status',
  '/vehicle/status/velocity_status',
  '/vehicle/status/battery_charge',
  // sensor
  '/sensing/number_of_sensor',
  '/sensing/imu/imu_data',
  // perception
  '/api/perception/objects',
  '/perception/traffic_light_recognition/judged/traffic_signals',
  // planning
  '/planning/path_candidate/goal_planner',
  // localization
  '/localization/kinematic_state',
  // map
  '/map/pointcloud_map',
  // lane departure
  '/diagnostics',
];

List<String> typeList = [
  // vehicle
  'autoware_adapi_v1_msgs/VehicleStatus',
  'autoware_vehicle_msgs/VelocityReport',
  'tier4_vehicle_msgs/BatteryStatus',
  // sensor
  'std_msgs/msg/Int8',
  'sensor_msgs/Imu',
  // perception
  'autoware_adapi_v1_msgs/DynamicObjectArray',
  'autoware_perception_msgs/TrafficLightGroupArray',
  // planning
  'autoware_planning_msgs/Path',
  // localization
  'nav_msgs/Odometry',
  // map
  'sensor_msgs/PointCloud2',
  // lane departure
  'diagnostic_msgs/DiagnosticArray',
];
