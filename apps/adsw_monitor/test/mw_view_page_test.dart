import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';

class FakeMwViewPage extends StatefulWidget {
  final MwCollector collector;

  const FakeMwViewPage({super.key, required this.collector});

  @override
  State<FakeMwViewPage> createState() => _FakeMwViewPageState();
}

class _FakeMwViewPageState extends State<FakeMwViewPage> {
  final Map<String, bool> _expandedSections = {
    'lifecycle': false,
    'ota': false,
    'security': false,
  };

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Obx(() => DataViewWidget(
                    title: 'Lifecycle Status',
                    icon: Icons.settings,
                    iconColor: const Color(0xFF34D399),
                    status: StatusType.good,
                    isExpanded: _expandedSections['lifecycle'] ?? false,
                    onTap: () => _toggleSection('lifecycle'),
                    children: [
                      KeyValueItem(
                        label: 'lifecycle_node',
                        value: widget.collector.topicData['Lifecycle status']?.toString() ?? '',
                      ),
                    ],
                  )),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Obx(() => DataViewWidget(
                    title: 'OTA Status',
                    icon: Icons.download,
                    iconColor: const Color(0xFF60A5FA),
                    status: StatusType.good,
                    isExpanded: _expandedSections['ota'] ?? false,
                    onTap: () => _toggleSection('ota'),
                    children: [
                      KeyValueItem(
                        label: 'System Version',
                        value: widget.collector.topicData['Ota status']?.toString() ?? '',
                      ),
                    ],
                  )),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Obx(() => DataViewWidget(
                    title: 'Security Status',
                    icon: Icons.lock,
                    iconColor: const Color(0xFFFBBF24),
                    status: StatusType.good,
                    isExpanded: _expandedSections['security'] ?? false,
                    onTap: () => _toggleSection('security'),
                    children: [
                      KeyValueItem(
                        label: 'Security Level',
                        value: widget.collector.topicData['Security status']?.toString() ?? '',
                      ),
                    ],
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class MockRos extends Mock implements Ros {}

class MockTopic extends Mock implements Topic {}

void main() {
  late MockRos mockRos;
  late MockTopic mockTopic;
  late MwCollector collector;

  setUp(() {
    mockRos = MockRos();
    mockTopic = MockTopic();

    Get.put<Ros>(mockRos);

    when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

    collector = MwCollector(topicFactory: (_, __, ___) => mockTopic);
  });

  testWidgets('FakeMwViewPage updates and expands correctly', (tester) async {
    collector.topicData['Lifecycle status'] = 'running';
    collector.topicData['Ota status'] = 'v1.0.0';
    collector.topicData['Security status'] = 'ok';

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(body: FakeMwViewPage(collector: collector)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lifecycle Status'), findsOneWidget);
    expect(find.text('OTA Status'), findsOneWidget);
    expect(find.text('Security Status'), findsOneWidget);

    await tester.tap(find.text('Lifecycle Status'));
    await tester.pump();
    await tester.tap(find.text('OTA Status'));
    await tester.pump();
    await tester.tap(find.text('Security Status'));
    await tester.pump();

    expect(find.text('lifecycle_node'), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(find.text('System Version'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('Security Level'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });
}
