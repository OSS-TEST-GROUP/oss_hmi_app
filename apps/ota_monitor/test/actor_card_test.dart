// QA(docs/qa): ota_monitor ActorCard 위젯 — 4 kind 의 Send 인터랙션(_onSend) +
// 필드 입력 + 응답 스트림 반영. collector.readyNotifier 로 Send 활성화.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/view/widgets/actor_card.dart';

class _MockRos extends Mock implements Ros {}

class _MockTopic extends Mock implements Topic {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(<String, dynamic>{});

  late OtaCollector collector;
  late Map<String, List<dynamic>> published;

  setUp(() async {
    Get.reset();
    published = {};
    final ros = _MockRos();
    Get.put<Ros>(ros);
    Topic factory(Ros r, String name, String type) {
      final t = _MockTopic();
      when(() => t.subscribe(any())).thenAnswer((_) async {});
      when(() => t.advertise()).thenAnswer((_) async {});
      when(() => t.publish(any())).thenAnswer((inv) async {
        (published[name] ??= []).add(inv.positionalArguments[0]);
      });
      return t;
    }

    collector = OtaCollector(topicFactory: factory, autoStartTimers: false);
    Get.put<OtaCollector>(collector);
    // autoStartTimers:false 라 onInit 이 publisher 를 안 만든다 — 테스트 seam 으로 직접 바인딩.
    await collector.startTopics(ros);
    collector.readyNotifier.value = true; // Send 활성화
  });

  tearDown(() {
    Get.delete<OtaCollector>(force: true);
    Get.reset();
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required OtaRequestKind kind,
    required List<ActorCardField> fields,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActorCard(
          cardKey: 'card_test',
          title: 'Test',
          fields: fields,
          sendKey: 'btn_send',
          responseKey: 'text_resp',
          kind: kind,
          collector: collector,
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> enterAndSend(WidgetTester tester, String fieldKey) async {
    await tester.enterText(find.byKey(Key(fieldKey)), 'ota_monitor');
    await tester.pump();
    final btn = find.byKey(const Key('btn_send'));
    await tester.ensureVisible(btn);
    await tester.tap(btn, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('getSettings: 입력 후 Send → 요청 publish', (tester) async {
    await pumpCard(tester,
        kind: OtaRequestKind.getSettings,
        fields: const [ActorCardField('app', keyName: 'f_app')]);
    await enterAndSend(tester, 'f_app');
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });

  testWidgets('setSettings: 값 필드 포함 Send', (tester) async {
    await pumpCard(tester, kind: OtaRequestKind.setSettings, fields: const [
      ActorCardField('app', keyName: 'f_app'),
      ActorCardField('value', keyName: 'f_val', multiline: true),
    ]);
    await tester.enterText(find.byKey(const Key('f_app')), 'ota_monitor');
    await tester.enterText(find.byKey(const Key('f_val')), 'automated=true');
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn_send')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });

  testWidgets('getState: Send', (tester) async {
    await pumpCard(tester,
        kind: OtaRequestKind.getState,
        fields: const [ActorCardField('app', keyName: 'f_app')]);
    await enterAndSend(tester, 'f_app');
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });

  testWidgets('setUpdate: Send', (tester) async {
    await pumpCard(tester,
        kind: OtaRequestKind.setUpdate,
        fields: const [ActorCardField('app', keyName: 'f_app')]);
    await enterAndSend(tester, 'f_app');
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });

  testWidgets('Send 후 매칭 응답 도착 → 응답 텍스트 표시(_onResponse)', (tester) async {
    await pumpCard(tester,
        kind: OtaRequestKind.getSettings,
        fields: const [ActorCardField('app', keyName: 'f_app')]);
    await enterAndSend(tester, 'f_app'); // requestAppSettings('ota_monitor') → _inflightId
    // 진행 중 요청 id 를 찾아 매칭되는 응답을 emit (ret_code:1 = OK).
    final id = collector.pendingRequests.keys.first;
    collector.onSettingsResponse({
      'id': id, 'app_name': 'ota_monitor',
      'app_settings': 'automated=true', 'ret_code': 1,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('text_resp')), findsOneWidget);
    expect(find.textContaining('app_settings'), findsWidgets);
  });

  testWidgets('selectedApp 주입 시 첫 필드 프리필', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActorCard(
          cardKey: 'card_test',
          title: 'Test',
          fields: const [ActorCardField('app', keyName: 'f_app')],
          sendKey: 'btn_send',
          responseKey: 'text_resp',
          kind: OtaRequestKind.getSettings,
          collector: collector,
          selectedApp: ValueNotifier<String?>('preselected_app'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('preselected_app'), findsOneWidget);
  });

  testWidgets('collector not-ready 면 Send 비활성(빈 입력)', (tester) async {
    collector.readyNotifier.value = false;
    await pumpCard(tester,
        kind: OtaRequestKind.getSettings,
        fields: const [ActorCardField('app', keyName: 'f_app')]);
    // 입력 없이 Send 시도 → 비활성 버튼(no publish).
    await tester.tap(find.byKey(const Key('btn_send')), warnIfMissed: false);
    await tester.pump();
    expect(published.values.expand((e) => e).isEmpty, isTrue);
  });
}
