import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class AdswCollector extends GetxController {
  late Ros ros = Get.find<Ros>();
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<SubscribeHandler> handlerList = [];
  RxString isLaneDeparture = 'false'.obs;

  final Topic Function(Ros ros, String name, String type) topicFactory;

  AdswCollector({
    required this.topicFactory,
  }) {
    handlerList = [
      handleVehicleStatus,
      handleCurrentVelocity,
      handleBattery,
      handleSensorCount,
      handleSensorStatus,
      handleObjectRecognition,
      handleTrafficLight,
      handlePlanningPath,
      handleLocalizationData,
      handleSpeedLimit,
      handleLaneDeparture,
    ];
  }

  void subscribeTopic(List<String> topics, List<String> types,
      List<SubscribeHandler> handlers) {
    for (int i = 0; i < topics.length; i++) {
      final topic = topicFactory(ros, topics[i], types[i]);
      topic.subscribe(handlers[i]);
    }
  }

  Future<void> handleVehicleStatus(Map<String, dynamic> msg) async {
    final gear = (msg['gear']?['status'] as num?)?.toInt();
    final ti = (msg['turn_indicators']?['status'] as num?)?.toInt();
    final hz = (msg['hazard_lights']?['status'] as num?)?.toInt();
    // final energy = (msg['energy_percentage'] as num?)?.toDouble();

    const gearText = {0: 'UNK', 1: 'N', 2: 'D', 3: 'R', 4: 'P', 5: 'L'};
    const tiText = {0: 'UNK', 1: 'OFF', 2: 'LEFT', 3: 'RIGHT'};
    const hzText = {0: 'UNK', 1: 'OFF', 2: 'ON'};

    topicData['Gear'] = gearText[gear] ?? '-';
    topicData['Turn indicator'] = tiText[ti] ?? '-';
    topicData['Hazard light'] = hzText[hz] ?? '-';
    // topicData['Energy %'] = energy?.toStringAsFixed(1);

    topicData['Steering tire angle'] = msg['steering_tire_angle'];
    //topicData['Bettery status'] = msg['energy_percentage'];
  }

  Future<void> handleCurrentVelocity(Map<String, dynamic> msg) async {
    topicData['Current velocity'] = msg['longitudinal_velocity'];
  }

  Future<void> handleBattery(Map<String, dynamic> msg) async {
    topicData['Battery status'] = msg['energy_level'];
  }

  Future<void> handleSensorCount(Map<String, dynamic> msg) async {
    topicData['Number of sensor'] = msg;
  }

  Future<void> handleSensorStatus(Map<String, dynamic> msg) async {
    topicData['Sensor status'] = msg;
  }

  Future<void> handleObjectRecognition(Map<String, dynamic> msg) async {
    topicData['Object recognition'] = msg['objects'];
  }

  Future<void> handleTrafficLight(Map<String, dynamic> msg) async {
    topicData['Traffic light'] = msg;
  }

  Future<void> handlePlanningPath(Map<String, dynamic> msg) async {
    topicData['Planning path'] = msg;
  }

  Future<void> handleLocalizationData(Map<String, dynamic> msg) async {
    topicData['Localization pose x'] = msg['pose']['pose']['position']['x'];
    topicData['Localization pose y'] = msg['pose']['pose']['position']['y'];
    topicData['Localization pose z'] = msg['pose']['pose']['position']['z'];
    topicData['Localization twist linear'] = msg['twist']['twist']['linear'];
    topicData['Localization twist angular'] = msg['twist']['twist']['angular'];
  }

  Future<void> handleSpeedLimit(Map<String, dynamic> msg) async {
    topicData['Speed limit'] = msg;
  }

  Future<void> handleLaneDeparture(Map<String, dynamic> msg) async {
    List statuses = msg['status'];

    for (var status in statuses) {
      if (status['name'] == 'lane_departure_checker: lane_departure') {
        String statusMsg = status['message'];
        List values = status['values'];

        String outOfLaneStr = values.firstWhere(
          (e) => e['key'] == 'is_out_of_lane',
          orElse: () => {'value': 'false'},
        )['value'];

        topicData['Lane departure'] = statusMsg;
        isLaneDeparture.value = outOfLaneStr;
      }
    }
  }
}
