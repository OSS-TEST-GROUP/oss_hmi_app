// QA(docs/qa): ota_monitor ClientPage 위젯 — 등록 카드/매니저 상태/heartbeat 렌더 + Register 인터랙션.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:ota_monitor/controller/client_service_controller.dart';
import 'package:ota_monitor/view/client_page.dart';

class _MockRos extends Mock implements Ros {}

class _MockTopic extends Mock implements Topic {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(<String, dynamic>{});

  late _MockRos ros;
  late ClientServiceController controller;
  late Map<String, List<dynamic>> published;

  setUp(() async {
    ros = _MockRos();
    published = {};
    Topic factory(Ros r, String name, String type) {
      final t = _MockTopic();
      when(() => t.subscribe(any())).thenAnswer((_) async {});
      when(() => t.advertise()).thenAnswer((_) async {});
      when(() => t.publish(any())).thenAnswer((inv) async {
        (published[name] ??= []).add(inv.positionalArguments[0]);
      });
      return t;
    }

    controller = ClientServiceController(ros: ros, topicFactory: factory);
    await controller.setup();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ClientPage(controller: controller)),
    ));
    await tester.pump();
  }

  testWidgets('등록 카드 + 매니저 상태 카드 렌더', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('card_client_register')), findsOneWidget);
    expect(find.byKey(const Key('card_client_manager_status')), findsOneWidget);
    expect(find.byKey(const Key('text_client_id')), findsOneWidget);
    expect(find.text('client_id: (not registered)'), findsOneWidget);
  });

  testWidgets('client_name/app_list 입력 후 Register → publish', (tester) async {
    await pump(tester);
    await tester.enterText(
        find.byKey(const Key('field_client_name')), 'ota_monitor');
    await tester.pump();
    final regBtn = find.byKey(const Key('btn_client_register'));
    await tester.ensureVisible(regBtn);
    await tester.tap(regBtn, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // setup() 되었으므로 register 는 registration 토픽으로 publish 한다.
    expect(published.values.expand((e) => e).isNotEmpty, isTrue);
  });

  testWidgets('registration 응답 주입 → client_id 표시 갱신', (tester) async {
    await pump(tester);
    controller.injectRegistrationResponseForTest(42);
    await tester.pump();
    expect(find.text('client_id: 42'), findsOneWidget);
  });

  testWidgets('manager ready 주입 → 상태 갱신(크래시 없음)', (tester) async {
    await pump(tester);
    controller.injectManagerReadyForTest();
    await tester.pump();
    expect(find.byKey(const Key('card_client_manager_status')), findsOneWidget);
  });
}
