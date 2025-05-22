import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oss_hmi_app/controllers/mw_collector.dart';
import 'package:oss_hmi_app/widgets/data_view_widget.dart';
import 'package:oss_hmi_app/models/key_value_item.dart';
import 'package:oss_hmi_app/data/mw_data.dart';

class MwViewPage extends StatefulWidget {
  const MwViewPage({super.key});
  
  @override
  MwViewPageState createState() => MwViewPageState();
}

class MwViewPageState extends State<MwViewPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  late final MwCollector _mwCollector;

  @override
  void initState() {
    
    super.initState();
    _startConnect();

  }

  void _startConnect() {

    _mwCollector = Get.put(MwCollector());
    final success = _mwCollector.connect("ws://172.16.10.170:9090"); // rosbridge server address

    if(success) {
      _startSubscribe();
    }

  }

  void _startSubscribe() {

    _mwCollector.subscribeTopic(topicList, typeList, _mwCollector.handlerList);    

  }

  @override
  Widget build(BuildContext context) {

    super.build(context);

    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Obx(() {
            return DataViewWidget(
              title: 'Lifecycle status',
              items: [
                KeyValueItem(keyLabel: 'Lifecycle status', value: _mwCollector.topicData['Ota status'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Ota status',
              items: [
                KeyValueItem(keyLabel: 'Ota status', value: _mwCollector.topicData['Ota status'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Security status',
              items: [
                KeyValueItem(keyLabel: 'Security status', value: _mwCollector.topicData['Ota status'].toString()),
              ]
            );}
          ),
        ],
      ),
    );
  }
}