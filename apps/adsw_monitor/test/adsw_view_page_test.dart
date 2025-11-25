import 'package:adsw_monitor/widget/key_value_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/adsw_collector.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';

class FakeAdswViewPage extends StatefulWidget {
  final AdswCollector collector;

  const FakeAdswViewPage({super.key, required this.collector});

  @override
  State<FakeAdswViewPage> createState() => _FakeAdswViewPageState();
}

class _FakeAdswViewPageState extends State<FakeAdswViewPage> {
  final Map<String, bool> _expandedSections = {
    'vehicle': false,
    'control': false,
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
        Obx(() {
          if (widget.collector.isLaneDeparture.value == 'true') {
            Future.microtask(
              () => showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Lane departure'),
                    content:
                        Text(widget.collector.topicData['Lane departure']),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text('ok'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
              ),
            );
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
                    KeyValueItem(
                      label: 'Gear',
                      value: widget.collector.topicData['Gear'].toString(),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
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
                    KeyValueItem(
                      label: 'Lane Departure',
                      value: widget.collector.topicData['Lane departure']
                          .toString(),
                    ),
                  ],
                );
              }),
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
  late AdswCollector collector;

  setUp(() {
    mockRos = MockRos();
    mockTopic = MockTopic();

    // Get에 mockRos 등록
    Get.reset();
    Get.put<Ros>(mockRos);

    // Topic.subscribe의 기본 동작 정의
    when(() => mockTopic.subscribe(any())).thenAnswer((_) async {});

    // Collector 생성
    collector = AdswCollector(
      topicFactory: (_, __, ___) => mockTopic,
    );
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'FakeAdswViewPage reflects topicData and shows lane departure dialog',
    (WidgetTester tester) async {
      // given: 초기 상태 (차선 이탈 X, 기어 D)
      collector.topicData['Gear'] = 'D';
      collector.isLaneDeparture.value = 'false';

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: FakeAdswViewPage(collector: collector),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 섹션 제목이 보이는지 확인
      expect(find.text('Vehicle'), findsOneWidget);
      expect(find.text('Control'), findsOneWidget);

      // Vehicle 섹션 확장
      await tester.tap(find.text('Vehicle'));
      await tester.pump();

      // Control 섹션 확장
      await tester.tap(find.text('Control'));
      await tester.pump();

      // Gear / Lane Departure 라벨 및 초기 값 확인
      expect(find.text('Gear'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('Lane Departure'), findsOneWidget);

      // when: topicData / isLaneDeparture 업데이트
      collector.topicData['Gear'] = 'P';
      collector.topicData['Lane departure'] = 'Out of lane!';
      collector.isLaneDeparture.value = 'true';

      // Obx 리렌더 + dialog microtask 처리
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // then: UI 값 업데이트 + 다이얼로그 표시 확인
      expect(find.text('P'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Lane departure'), findsOneWidget);
      expect(find.text('Out of lane!'), findsNWidgets(2)); // 본문 + 컨트롤 섹션

      // when: close 버튼 눌러 다이얼로그 닫기
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();

      // then: 다이얼로그는 사라지지만 값은 유지
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('Out of lane!'), findsOneWidget);
    },
  );
}
