import 'package:flutter/material.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class AdswCollector extends GetxController {
  late Ros ros;
  RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<String> topicList = [];
  List<String> typeList = [];
  List<SubscribeHandler> handlerList = [];
  
  bool connect(String url) {

    ros = Ros(url: url);
    ros.connect();

    handlerList = [handleGear, handleTrafficLight];

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


  Future<void> handleSteeringTireAngle(Map<String, dynamic> msg) async {}

  Future<void> handleCurrentVelocity(Map<String, dynamic> msg) async {}

  Future<void> handleGear(Map<String, dynamic> msg) async {}

  Future<void> handleHazardLight(Map<String, dynamic> msg) async {}

  Future<void> handleTurnIndicator(Map<String, dynamic> msg) async {}

  Future<void> handleBattery(Map<String, dynamic> msg) async {}

  Future<void> handleSensorCount(Map<String, dynamic> msg) async {}

  Future<void> handleSensorStatus(Map<String, dynamic> msg) async {}

  Future<void> handleObjectRecognition(Map<String, dynamic> msg) async {}

  Future<void> handleTrafficLight(Map<String, dynamic> msg) async {}

  Future<void> handlePlanningPath(Map<String, dynamic> msg) async {}

  Future<void> handleLocaliPose(Map<String, dynamic> msg) async {}

  Future<void> handleLocaliTwist(Map<String, dynamic> msg) async {}

  Future<void> handleSpeedLimit(Map<String, dynamic> msg) async {}

}