import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

class FakeMwViewPage extends StatefulWidget {
  final MwCollector collector;

  const FakeMwViewPage({super.key, required this.collector});

  @override
  State<FakeMwViewPage> createState() => _FakeMwViewPageState();
}

class _FakeMwViewPageState extends State<FakeMwViewPage> {
  final Map<String, bool> _expandedSections = {
    'diagnostic': false,
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
              DataViewWidget(
                title: 'Diagnostic Status',
                icon: Icons.settings,
                iconColor: const Color(0xFF34D399),
                status: StatusType.error,
                isExpanded: _expandedSections['diagnostic'] ?? false,
                onTap: () => _toggleSection('diagnostic'),
                children: [
                  Obx(() {
                    // 현 API: collector.diagnostics (List<Map>) 직접 순회
                    // (구버전 diagNames/topicData 게터는 제거됨).
                    final entries = widget.collector.diagnostics.toList();
                    if (entries.isEmpty) {
                      // ✅ 리스트 오기 전 상태
                      return const KeyValueItem(
                        label: 'Waiting for diagnostic list…',
                        value: '-',
                      );
                    }

                    StatusType statusOf(int? s) {
                      // MwViewPage에서 쓰는 매핑과 동일
                      switch (s) {
                        case 1:
                          return StatusType.good;
                        case 3:
                          return StatusType.warning;
                        case 2:
                          return StatusType.error;
                        default:
                          return StatusType.good;
                      }
                    }

                    String subtitle(Map raw) {
                      final code = raw['code'];
                      final retT = raw['ret_text'];
                      final msg = raw['message'];

                      final lines = <String>[];
                      lines.add('code: ${code ?? '-'} ret: ${retT ?? '-'}');
                      if (msg != null && (msg as String).isNotEmpty) {
                        lines.add('msg: $msg');
                      }
                      return lines.join('\n');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final raw in entries)
                          KeyValueItem(
                            label: '${raw['name'] ?? '-'}',
                            value: raw['status_text'] != null
                                ? raw['status_text'] as String
                                : '-',
                            subtitle: subtitle(raw),
                            status: statusOf(raw['status'] as int?),
                          ),
                      ],
                    );
                  }),
                ],
              ),
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
    TestWidgetsFlutterBinding.ensureInitialized();

    mockRos = MockRos();
    mockTopic = MockTopic();

    Get.reset();
    Get.put<Ros>(mockRos);

    // MwCollector.onInit에서 사용하는 메소드들 스텁 처리
    when(() => mockTopic.advertise())
        .thenAnswer((_) => Future<void>.value());
    when(() => mockTopic.unadvertise())
        .thenAnswer((_) => Future<void>.value());
    when(() => mockTopic.publish(any()))
        .thenAnswer((_) => Future<void>.value());
    when(() => mockTopic.subscribe(any()))
        .thenAnswer((_) async {});
    when(() => mockTopic.unsubscribe())
        .thenAnswer((_) => Future<void>.value());

    // 모든 topicFactory 호출에서 같은 mockTopic을 돌려줘도 무방
    collector = MwCollector(
      topicFactory: (_, __, ___) => mockTopic,
    );
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'FakeMwViewPage shows waiting message then renders diagnostic entries',
    (WidgetTester tester) async {
      // given: 초기에는 diagNames 비어 있음 → "Waiting..."이 나와야 함
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: FakeMwViewPage(collector: collector),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 섹션 제목 존재 확인
      expect(find.text('Diagnostic Status'), findsOneWidget);

      // 섹션 확장
      await tester.tap(find.text('Diagnostic Status'));
      await tester.pump();

      // 리스트가 비어 있을 때의 안내 문구 확인
      expect(find.text('Waiting for diagnostic list…'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);

      // when: diagnostics 를 채워서 실제 진단 정보가 들어온 상황을 시뮬레이션
      collector.diagnostics.assignAll([
        {
          'name': 'EngineStatus',
          'code': 10,
          'ret_code': 1,
          'ret_text': 'PASS',
          'status': 2,
          'status_text': 'FATAL',
          'message': 'Overheated',
        },
      ]);

      await tester.pump(); // Obx 리렌더

      // then: "Waiting..." 대신 실제 항목이 렌더링되어야 함
      expect(find.text('Waiting for diagnostic list…'), findsNothing);

      // 라벨 / 값 / 서브타이틀 확인
      expect(find.text('EngineStatus'), findsOneWidget);
      expect(find.text('FATAL'), findsOneWidget);

      // subtitle 텍스트 (code / ret / msg 요약)
      expect(find.textContaining('code: 10 ret: PASS'), findsOneWidget);
      expect(find.textContaining('msg: Overheated'), findsOneWidget);
    },
  );
}
