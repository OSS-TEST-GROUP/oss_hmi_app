import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/model/key_value_item.dart';
import 'package:adsw_monitor/data/mw_data.dart';

class MwViewPage extends StatefulWidget {
  const MwViewPage({super.key});
  
  @override
  MwViewPageState createState() => MwViewPageState();
}

class MwViewPageState extends State<MwViewPage> with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  late final MwCollector _mwCollector;

  final Map<String, bool> _expandedSections = {
    'lifecycle': false,
    'ota': false,
    'security': false
  };

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
          // Left Column - Lifecycle
          Expanded(
            child: Column(
              children: [
                DataViewWidget(
                  title: 'Lifecycle Status',
                  icon: Icons.settings,
                  iconColor: const Color(0xFF34D399),
                  status: StatusType.error,
                  isExpanded: _expandedSections['lifecycle'] ?? false,
                  onTap: () => _toggleSection('lifecycle'),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Node Status:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    KeyValueItem(label: 'perception_node', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'planning_node', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'control_node', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'localization_node', value: _mwCollector.topicData['Ota status'].toString(), status: StatusType.error),
                    KeyValueItem(label: 'sensor_fusion', value: _mwCollector.topicData['Ota status'].toString(), status: StatusType.warning),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F1D1D).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Abnormal Nodes:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF87171),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'localization_node: Connection timeout',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFCA5A5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Center Column - OTA
          Expanded(
            child: Column(
              children: [
                DataViewWidget(
                  title: 'OTA Status',
                  icon: Icons.download,
                  iconColor: const Color(0xFF60A5FA),
                  status: StatusType.good,
                  isExpanded: _expandedSections['ota'] ?? false,
                  onTap: () => _toggleSection('ota'),
                  children: [
                    KeyValueItem(label: 'System Version', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Last Update', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Perception', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Planning', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Control', value: _mwCollector.topicData['Ota status'].toString(), status: StatusType.warning),
                    KeyValueItem(label: 'Map', value: _mwCollector.topicData['Ota status'].toString()),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        'Next update: 2024-12-22',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right Column - Security
          Expanded(
            child: Column(
              children: [
                DataViewWidget(
                  title: 'Security Status',
                  icon: Icons.lock,
                  iconColor: const Color(0xFFFBBF24),
                  status: StatusType.warning,
                  isExpanded: _expandedSections['security'] ?? false,
                  onTap: () => _toggleSection('security'),
                  children: [
                    KeyValueItem(label: 'Security Level', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Encryption', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Certificate', value: _mwCollector.topicData['Ota status'].toString()),
                    KeyValueItem(label: 'Intrusion Det', value: _mwCollector.topicData['Ota status'].toString(), status: StatusType.warning),
                    KeyValueItem(label: 'Firewall', value: _mwCollector.topicData['Ota status'].toString()),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF78350F).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withOpacity(0.3),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Alert:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFBBF24),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Unusual network activity at 14:32',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFFDE68A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}