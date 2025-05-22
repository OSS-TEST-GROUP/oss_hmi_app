// import 'package:flutter/material.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class AdswCollector extends GetxController {
  late Ros ros;
  final RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<SubscribeHandler> handlerList = [];
  
  bool connect(String url) {

    ros = Ros(url: url);
    ros.connect();

    handlerList = [handleSteeringTireAngle, handleCurrentVelocity, handleGear, handleHazardLight,
                    handleTurnIndicator, handleBattery, handleSensorCount, handleSensorStatus,
                    handleObjectRecognition, handleTrafficLight, handlePlanningPath, handleLocaliPose,
                    handleLocaliTwist, handleSpeedLimit];

    return true;
  }

  void subscribeTopic(List<String> topics, List<String> types, List<SubscribeHandler> handlers){

    for(int i=0;i<topics.length;i++) {
      Topic testTopic = Topic(
        ros: ros, 
        name: topics[i], 
        type: types[i]);
      testTopic.subscribe(handlers[i]);
    }

  }

  Future<void> handleSteeringTireAngle(Map<String, dynamic> msg) async {

    topicData['Steering tire angle'] = msg;

  }

  Future<void> handleCurrentVelocity(Map<String, dynamic> msg) async {

    topicData['Current velocity'] = msg;

  }

  Future<void> handleGear(Map<String, dynamic> msg) async {

    topicData['Gear'] = msg['status'];

  }

  Future<void> handleHazardLight(Map<String, dynamic> msg) async {

    topicData['Hazard light'] = msg;

  }

  Future<void> handleTurnIndicator(Map<String, dynamic> msg) async {

    topicData['Turn indicator'] = msg;

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

  Future<void> handleLocaliPose(Map<String, dynamic> msg) async {

    topicData['Localization pose'] = msg;

  }

  Future<void> handleLocaliTwist(Map<String, dynamic> msg) async {

    topicData['Localization twist'] = msg;

  }

  Future<void> handleSpeedLimit(Map<String, dynamic> msg) async {

    topicData['Speed limit'] = msg;

  }

}