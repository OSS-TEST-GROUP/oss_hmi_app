  List<String> topicList = [
    // vehicle
    'steering_tire_angle', 
    '/vehicle/status/velocity_status', 
    'gear', 
    'hazard_light', 
    'turn_indicator', 
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
    'localization_pose', 
    'localization_twist', 
    // map
    'speed_limit',
    // lane departure
    '/diagnostics'
    ];

  List<String> typeList = [
    // vehicle
    'test_msg/SteeringTireAngle',
    'autoware_vehicle_msgs/VelocityReport',
    'test_msg/Gear',
    'test_msg/HazardLight',
    'test_msg/TurnIndicator',
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
    'test_msg/LocalizationPose',
    'test_msg/LocalizationTwist',
    // map
    'test_msg/SpeedLimit',
    // lane departure
    'diagnostic_msgs/DiagnosticArray'
    ];