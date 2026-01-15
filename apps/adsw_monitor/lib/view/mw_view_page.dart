// coverage:ignore-file

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
    'ota': false,
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
          Expanded(
            child: Column(
              children: [
                Obx(() {
                  final names = _mwCollector.diagNames.toList();
                  final logs = _mwCollector.diagLogs.toList();

                  StatusType _statusOf(int? s) {
                    switch (s) {
                      case 1: return StatusType.good;
                      case 3: return StatusType.warning;
                      case 2: return StatusType.error;
                      default: return StatusType.good;
                    }
                  }

                  String? _subtitle(dynamic raw) {
                    if (raw is! Map) return null;
                    //final name = raw['name'];
                    final code = raw['code'];
                    final retT = raw['ret_text'];
                    final msg = raw['message'];

                    final lines = <String>[];
                    //if (name != null) lines.add('name: $name');
                    lines.add('code: ${code ?? '-'} ret: ${retT ?? '-'}');
                    //if (msg != null && (msg as String).isNotEmpty) lines.add('msg: $msg');
                    if (msg != null && ('$msg').isNotEmpty) {
                      lines.add('msg: $msg');
                    }

                    return lines.join('\n');
                  }

                  final List<Widget> children = logs.isEmpty
                      ? const [
                          KeyValueItem(
                            label: 'Waiting for diagnostic messages...',
                            value: '-',
                          ),
                        ]
                      : [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in logs)
                                Builder(builder: (_) {
                                  final int? statusNum = (item['status'] is num)
                                      ? (item['status'] as num).toInt()
                                      : (item['status'] as int?);

                                  final value =
                                      item['status_text']?.toString() ?? '-';

                                  final label = item['name']?.toString() ??
                                      'unknown';

                                  return KeyValueItem(
                                    label: label,
                                    value: value,
                                    subtitle: _subtitle(item),
                                    status: _statusOf(statusNum),
                                  );
                                }),
                            ],
                          ),
                        ];

                  final List<Widget> children2 = names.isEmpty
                    ? const [
                      KeyValueItem(label: 'Waiting for diagnostic list...', value: '-'),
                    ]
                    : [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final name in names)
                            Builder(builder: (_) {
                              final raw = _mwCollector.topicData[name];

                              final int? statusNum = (raw is Map)
                                ? (raw['status'] as num?)?.toInt()
                                : (raw is num ? raw.toInt() : null);

                              final value = (raw is Map)
                                ? (raw['status_text']?.toString() ?? '-')
                                : (raw?.toString() ?? '-');

                              return KeyValueItem(
                                label: name,
                                value: value,
                                subtitle: _subtitle(raw),
                                status: _statusOf(statusNum),
                              );
                            }),
                        ],
                      ),
                    ];

                  return DataViewWidget(
                    title: 'Diagnostic Status',
                    icon: Icons.settings,
                    iconColor: const Color(0xFF34D399),
                    status: StatusType.error,
                    isExpanded: _expandedSections['diagnostic'] ?? false,
                    onTap: () => _toggleSection('diagnostic'),
                    children: children,
                  );
                }),
                const SizedBox(height: 20),
                Obx(() {
                  return DataViewWidget(
                    title: 'Ota Status', 
                    icon: Icons.arrow_circle_up, 
                    iconColor: const Color.fromARGB(255, 66, 165, 245), 
                    status: StatusType.warning, 
                    isExpanded: _expandedSections['ota'] ?? false, 
                    onTap: () => _toggleSection('ota'), 
                    children: [
                      KeyValueItem(
                          label: 'test',
                          value:
                              _mwCollector.topicData['Ota status'].toString()
                      ),
                    ],
                  );
                })
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
