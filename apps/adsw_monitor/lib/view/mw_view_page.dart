import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';
//import 'package:adsw_monitor/data/mw_data.dart';
import 'package:roslibdart/roslibdart.dart';

class MwViewPage extends StatefulWidget {
  const MwViewPage({
    super.key,
  });

  @override
  MwViewPageState createState() => MwViewPageState();
}

class MwViewPageState extends State<MwViewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final MwCollector _mwCollector;

  final Map<String, bool> _expandedSections = {
    'diagnostic': false,
    'security': false,
  };

  @override
  void initState() {
    super.initState();
    _startConnect();
  }

  void _startConnect() {
    // _mwCollector = MwCollector(
    //   topicFactory: (ros, name, type) =>
    //       Topic(ros: ros, name: name, type: type),
    // );
    //_startSubscribe();

    _mwCollector = Get.put(
      MwCollector(
        topicFactory: (ros, name, type) =>
            Topic(ros: ros, name: name, type: type),
      ),
    );
  }

  // void _startSubscribe() {
  //   _mwCollector.subscribeTopic(topicList, typeList, _mwCollector.handlerList);
  // }

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
                  title: 'Diagnostic Status',
                  icon: Icons.settings,
                  iconColor: const Color(0xFF34D399),
                  status: StatusType.error,
                  isExpanded: _expandedSections['diagnostic'] ?? false,
                  onTap: () => _toggleSection('diagnostic'),
                  children: [
                    Obx(() {
                      final names = _mwCollector.diagNames.toList();
                      if (names.isEmpty) {
                        // ✅ 리스트 오기 전
                        return const KeyValueItem(
                          label: 'Waiting for diagnostic list…',
                          value: '-',
                          // 필요하면 status: StatusType.warning,
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final name in names)
                            KeyValueItem(
                              label: name, // diag name
                              value: (_mwCollector.topicData[name] ?? '-')
                                  .toString(), // status
                              status: StatusType.good, // 필요시 status 매핑 로직 추가
                            ),
                        ],
                      );
                    })
                  ],
                )
              ],
            ),
          ),
          // const SizedBox(width: 24),
          // // Right Column - Security
          // Expanded(
          //   child: Column(
          //     children: [
          //       Obx(() {
          //         return DataViewWidget(
          //           title: 'Security Status',
          //           icon: Icons.lock,
          //           iconColor: const Color(0xFFFBBF24),
          //           status: StatusType.warning,
          //           isExpanded: _expandedSections['security'] ?? false,
          //           onTap: () => _toggleSection('security'),
          //           children: [
          //             KeyValueItem(
          //                 label: 'Security Level',
          //                 value:
          //                     _mwCollector.topicData['Ota status'].toString()),
          //             KeyValueItem(
          //                 label: 'Encryption',
          //                 value:
          //                     _mwCollector.topicData['Ota status'].toString()),
          //             KeyValueItem(
          //                 label: 'Certificate',
          //                 value:
          //                     _mwCollector.topicData['Ota status'].toString()),
          //             KeyValueItem(
          //                 label: 'Intrusion Det',
          //                 value:
          //                     _mwCollector.topicData['Ota status'].toString(),
          //                 status: StatusType.warning),
          //             KeyValueItem(
          //                 label: 'Firewall',
          //                 value:
          //                     _mwCollector.topicData['Ota status'].toString()),
          //             const SizedBox(height: 8),
          //             Container(
          //               padding: const EdgeInsets.all(8),
          //               decoration: BoxDecoration(
          //                 color: const Color(0xFF78350F).withOpacity(0.3),
          //                 borderRadius: BorderRadius.circular(4),
          //                 border: Border.all(
          //                   color: const Color(0xFFFBBF24).withOpacity(0.3),
          //                 ),
          //               ),
          //               child: const Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   Text(
          //                     'Security Alert:',
          //                     style: TextStyle(
          //                       fontSize: 12,
          //                       color: Color(0xFFFBBF24),
          //                       fontWeight: FontWeight.w500,
          //                     ),
          //                   ),
          //                   SizedBox(height: 4),
          //                   Text(
          //                     'Unusual network activity at 14:32',
          //                     style: TextStyle(
          //                       fontSize: 10,
          //                       color: Color(0xFFFDE68A),
          //                     ),
          //                   ),
          //                 ],
          //               ),
          //             ),
          //           ],
          //         );
          //       }),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}
