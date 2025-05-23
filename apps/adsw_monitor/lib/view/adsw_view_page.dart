import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/adsw_collector.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/model/key_value_item.dart';
import 'package:adsw_monitor/data/adsw_data.dart';

class AdswViewPage extends StatefulWidget {
  const AdswViewPage({super.key});
  
  @override
  State<AdswViewPage> createState() => _AdswViewPageState();
}

class _AdswViewPageState extends State<AdswViewPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  late final AdswCollector _adswCollector;

  @override
  void initState() {

    super.initState();
    _startConnect();

  }

  void _startConnect() {

    _adswCollector = Get.put(AdswCollector());
    final success = _adswCollector.connect("ws://172.16.10.170:9090"); // rosbridge server address

    if(success) {
      _startSubscribe();
    }

  }

  void _startSubscribe() {

    _adswCollector.subscribeTopic(topicList, typeList, _adswCollector.handlerList);

  }

  @override
  Widget build(BuildContext context) {

    super.build(context);

    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Obx(() {
            return DataViewWidget(
              title: 'Vehicle',
              items: [
                KeyValueItem(keyLabel: 'Steering tire angle', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Current velocity', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Gear', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Hazard light', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Turn indicator', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Battery status', value: _adswCollector.topicData['Gear'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Sensor',
              items: [
                KeyValueItem(keyLabel: 'Number of sensor', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Sensor status', value: _adswCollector.topicData['Gear'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Perception',
              items: [
                KeyValueItem(keyLabel: 'Object recognition', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Traffic light', value: _adswCollector.topicData['Gear'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Planning',
              items: [
                KeyValueItem(keyLabel: 'Planning path', value: _adswCollector.topicData['Gear'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Localization',
              items: [
                KeyValueItem(keyLabel: 'Localization pose', value: _adswCollector.topicData['Gear'].toString()),
                KeyValueItem(keyLabel: 'Localization twist', value: _adswCollector.topicData['Gear'].toString()),
              ]
            );}
          ),
          Obx(() {
            return DataViewWidget(
              title: 'Map',
              items: [
                KeyValueItem(keyLabel: 'Speed limit', value: _adswCollector.topicData['Gear'].toString()),
              ]
            );}
          ),
        ],
      ),
    );
  }
}