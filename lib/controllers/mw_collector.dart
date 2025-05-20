import 'package:flutter/material.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class MwCollector extends GetxController {
  late Ros ros;
  RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<String> topicList = [];
  List<String> typeList = [];
  List<SubscribeHandler> handlerList = [];
  
  bool connect(String url) {

    ros = Ros(url: url);
    ros.connect();

    handlerList = [handleOta];

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

  Future<void> handleLifecycle(Map<String, dynamic> msg) async {}

  Future<void> handleOta(Map<String, dynamic> msg) async {}

  Future<void> handleSecurity(Map<String, dynamic> msg) async {}

}