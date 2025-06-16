import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class AdswCollector extends GetxController {
  late Ros ros;
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<SubscribeHandler> handlerList = [];
  RxString isLaneDeparture = 'false'.obs;

  final Topic Function(Ros ros, String name, String type) topicFactory;

  AdswCollector({required this.topicFactory});
  
  bool connect(String url) {

    ros = Ros(url: url);
    ros.connect();

    handlerList = [handleVehicleStatus, handleCurrentVelocity, handleBattery, handleSensorCount, 
                    handleSensorStatus, handleObjectRecognition, handleTrafficLight, handlePlanningPath, 
                    handleLocalizationData, handleSpeedLimit, handleLaneDeparture];

    return true;
  }

  void subscribeTopic(List<String> topics, List<String> types, List<SubscribeHandler> handlers){

    for(int i=0;i<topics.length;i++) {
      final topic = topicFactory(ros, topics[i], types[i]);
      topic.subscribe(handlers[i]);
    }

  }

  Future<void> handleVehicleStatus(Map<String, dynamic> msg) async {

    topicData['Gear'] = msg['gear']['status'];
    topicData['Steering tire angle'] = msg['steering_tire_angle'];
    topicData['Turn indicator'] = msg['turn_indicators'];
    topicData['Hazard light'] = msg['hazard_lights'];

  }

  Future<void> handleCurrentVelocity(Map<String, dynamic> msg) async {

    topicData['Current velocity'] = msg;

  }

  Future<void> handleBattery(Map<String, dynamic> msg) async {

    topicData['Battery status'] = msg;

  }

  Future<void> handleSensorCount(Map<String, dynamic> msg) async {

    topicData['Number of sensor'] = msg;

  }

  Future<void> handleSensorStatus(Map<String, dynamic> msg) async {

    topicData['Sensor status'] = msg;

  }

  Future<void> handleObjectRecognition(Map<String, dynamic> msg) async {

    topicData['Object recognition'] = msg;

  }

  Future<void> handleTrafficLight(Map<String, dynamic> msg) async {

    topicData['Traffic light'] = msg;

  }

  Future<void> handlePlanningPath(Map<String, dynamic> msg) async {

    topicData['Planning path'] = msg;

  }

  Future<void> handleLocalizationData(Map<String, dynamic> msg) async {

    topicData['Localization pose'] = msg['pose'];
    topicData['Localization twist'] = msg['twist'];

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