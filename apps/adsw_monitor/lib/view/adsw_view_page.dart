import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/adsw_collector.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';
import 'package:adsw_monitor/data/adsw_data.dart';
import 'package:roslibdart/roslibdart.dart';

class AdswViewPage extends StatefulWidget {
  const AdswViewPage({super.key,});
  
  @override
  State<AdswViewPage> createState() => _AdswViewPageState();
}

class _AdswViewPageState extends State<AdswViewPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  late final AdswCollector _adswCollector;

  final Map<String, bool> _expandedSections = {
    'vehicle': false,
    'sensor': false,
    'perception': false,
    'planning': false,
    'localization': false,
    'map': false,
    'control': false
  };

  @override
  void initState() {

    super.initState();
    _startConnect();

  }

  void _startConnect() {

    _adswCollector = AdswCollector(
      topicFactory: (ros, name, type) => Topic(ros: ros, name: name, type: type),
    );
    _startSubscribe();

  }

  void _startSubscribe() {

    _adswCollector.subscribeTopic(topicList, typeList, _adswCollector.handlerList);

  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {

    super.build(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            if(_adswCollector.isLaneDeparture.value == 'true'){
              Future.microtask(() => showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Lane departure'),
                    content: Text(_adswCollector.topicData['Lane departure']),
                    actions: <Widget>[
                      TextButton(
                        style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.labelLarge),
                        child: const Text('close'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.labelLarge),
                        child: const Text('ok'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              ));
              return const SizedBox();
            } else {
              return const SizedBox();
            }
          }),
          Expanded(
            child: Column(
              children: [
                Obx(() {
                  return DataViewWidget(
                    title: 'Vehicle',
                    icon: Icons.directions_car,
                    iconColor: const Color(0xFF60A5FA),
                    status: StatusType.good,
                    isExpanded: _expandedSections['vehicle'] ?? false,
                    onTap: () => _toggleSection('vehicle'),
                    children: [
                      KeyValueItem(label: 'Steering Tire Angle', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Currnet Velocity', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Gear', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Hazard Light', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Turn Indicator', value: _adswCollector.topicData['Gear'].toString(), status: StatusType.warning),
                      KeyValueItem(label: 'Battery Status', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Obx(() {
                  return DataViewWidget(
                    title: 'Sensor',
                    icon: Icons.sensors,
                    iconColor: const Color(0xFF34D399),
                    status: StatusType.warning,
                    isExpanded: _expandedSections['sensor'] ?? false,
                    onTap: () => _toggleSection('sensor'),
                    children: [
                      KeyValueItem(label: 'Total Sensors', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Active', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Camera', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'LiDAR', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Radar', value: _adswCollector.topicData['Gear'].toString(), status: StatusType.warning),
                      KeyValueItem(label: 'GPS', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Center-Left Column
          Expanded(
            child: Column(
              children: [
                Obx(() {
                  return DataViewWidget(
                    title: 'Perception',
                    icon: Icons.visibility,
                    iconColor: const Color(0xFFA78BFA),
                    status: StatusType.good,
                    isExpanded: _expandedSections['perception'] ?? false,
                    onTap: () => _toggleSection('perception'),
                    children: [
                      KeyValueItem(label: 'Objects', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Vehicles', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Pedestrians', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Cyclists', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Traffic Light', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Obx(() {
                  return DataViewWidget(
                    title: 'Planning',
                    icon: Icons.route,
                    iconColor: const Color(0xFFFB923C),
                    status: StatusType.good,
                    isExpanded: _expandedSections['planning'] ?? false,
                    onTap: () => _toggleSection('planning'),
                    children: [
                      KeyValueItem(label: 'Path Status', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Next Action', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Distance', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Horizon', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Center-Right Column
          Expanded(
            child: Column(
              children: [
                Obx(() {
                  return DataViewWidget(
                    title: 'Localization',
                    icon: Icons.location_on,
                    iconColor: const Color(0xFF22D3EE),
                    status: StatusType.good,
                    isExpanded: _expandedSections['localization'] ?? false,
                    onTap: () => _toggleSection('localization'),
                    children: [
                      KeyValueItem(label: 'X Position', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Y Position', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Heading', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Linear Vel', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Angular Vel', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Obx(() {
                  return DataViewWidget(
                    title: 'Map',
                    icon: Icons.map,
                    iconColor: const Color(0xFF818CF8),
                    status: StatusType.good,
                    isExpanded: _expandedSections['map'] ?? false,
                    onTap: () => _toggleSection('map'),
                    children: [
                      KeyValueItem(label: 'Speed Limit', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Road Type', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Lane Count', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Map Version', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Column
          Expanded(
            child: Column(
              children: [
                Obx(() {
                  return DataViewWidget(
                    title: 'Control',
                    icon: Icons.security,
                    iconColor: const Color(0xFFF87171),
                    status: StatusType.good,
                    isExpanded: _expandedSections['control'] ?? false,
                    onTap: () => _toggleSection('control'),
                    children: [
                      KeyValueItem(label: 'Lane Departure', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Steering Cmd', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Throttle Cmd', value: _adswCollector.topicData['Gear'].toString()),
                      KeyValueItem(label: 'Brake Cmd', value: _adswCollector.topicData['Gear'].toString()),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      )
    );
  }
}