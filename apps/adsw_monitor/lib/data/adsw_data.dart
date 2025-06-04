  List<String> topicList = [
    // vehicle
    '/api/vehicle/status', 
    '/vehicle/status/velocity_status', 
    '/vehicle/status/battery_charge', 
    // sensor
    'number_of_sensor', 
    'sensor_status', 
    // perception
    '/api/perception/objects', 
    '/perception/traffic_light_recognition/judged/traffic_signals', 
    // planning
    '/planning/path_candidate/*', 
    // localization
    '/localization/kinematic_state', 
    // map
    'speed_limit',
    // lane departure
    '/diagnostics'
    ];

  List<String> typeList = [
    // vehicle
    'autoware_adapi_v1_msgs/VehicleStatus',
    'autoware_vehicle_msgs/VelocityReport',
    'tier4_vehicle_msgs/BatteryStatus',
    // sensor
    'test_msg/NumberOfSensor',
    'test_msg/SensorStatus',
    // perception
    'autoware_adapi_v1_msgs/DynamicObjectArray',
    'autoware_perception_msgs/TrafficLightGroupArray',
    // planning
    'autoware_planning_msgs/Path',
    // localization
    'nav_msgs/Odometry',
    // map
    'test_msg/SpeedLimit',
    // lane departure
    'diagnostic_msgs/DiagnosticArray'
    ];