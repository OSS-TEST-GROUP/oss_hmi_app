import 'package:roslibdart/roslibdart.dart';
import 'package:get/get.dart';

class MwCollector extends GetxController {
  late Ros ros;
  RxMap<String, dynamic> topicData = <String, dynamic>{}.obs;
  List<SubscribeHandler> handlerList = [];

  final Topic Function(Ros ros, String name, String type) topicFactory;

  MwCollector({required this.topicFactory});
  
  bool connect(String url) {

    ros = Ros(url: url);
    ros.connect();

    handlerList = [handleLifecycle, handleOta, handleSecurity];

    return true;
  }

  void subscribeTopic(List<String> topics, List<String> types, List<SubscribeHandler> handlers){

    for(int i=0;i<topics.length;i++) {
      final topic = topicFactory(ros, topics[i], types[i]);
      topic.subscribe(handlers[i]);
      // Topic testTopic = Topic(
      //   ros: ros, 
      //   name: topics[i], 
      //   type: types[i]);
      // testTopic.subscribe(handlers[i]);
    }

  }

  Future<void> handleLifecycle(Map<String, dynamic> msg) async {

    topicData['Lifecycle status'] = msg;

  }

  Future<void> handleOta(Map<String, dynamic> msg) async {

    topicData['Ota status'] = msg;
  
  }

  Future<void> handleSecurity(Map<String, dynamic> msg) async {

    topicData['Security status'] = msg;

    // 보안 문제 검사 코드

  }

}