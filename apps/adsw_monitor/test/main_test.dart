
// // class MockRos extends Mock implements Ros {}

// // void main() {
// //   testWidgets('Tab switching works with stubbed pages', (WidgetTester tester) async {
// //     final ros = MockRos();

// //     await tester.pumpWidget(TestableHomePage(ros: ros));

// //     // AD SW Info is visible initially
// //     expect(find.byKey(const Key('FakeAdswViewPage')), findsOneWidget);
// //     expect(find.byKey(const Key('FakeMwViewPage')), findsNothing);

// //     // Tap second tab
// //     await tester.tap(find.text('Diagnostic Info'));
// //     await tester.pumpAndSettle();

// //     // Diagnostic tab should now be shown
// //     expect(find.byKey(const Key('FakeAdswViewPage')), findsNothing);
// //     expect(find.byKey(const Key('FakeMwViewPage')), findsOneWidget);
// //   });
// // }

import 'package:adsw_monitor/config/app_config.dart';
import 'package:adsw_monitor/main.dart';
import 'package:adsw_monitor/ros_keeper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get/get.dart';


class MockRos extends Mock implements Ros {}

/// 실제 네트워크 연결 없이 start 호출 여부 + ros 등록을 테스트하기 위한 RosKeeper 더미
class TestRosKeeper extends RosKeeper {
  TestRosKeeper(super.cfg, this.mockRos);

  final MockRos mockRos;
  bool startCalled = false;

  @override
  Future<void> start() async {
    startCalled = true;
    // 실제 Ros 연결 X
  }

  // 내부 _ros 대신 우리가 넣어준 mockRos를 그대로 반환
  @override
  Ros get ros => mockRos;
}

/// Fake 페이지: 탭 콘텐츠 대신 간단한 위젯만 렌더링
class FakeAdswViewPage extends StatelessWidget {
  const FakeAdswViewPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('FakeAdswViewPage'));
}

class FakeMwViewPage extends StatelessWidget {
  const FakeMwViewPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('FakeMwViewPage'));
}

void main() {
  setUp(() {
    Get.reset();
  });

  // 바인딩 초기화
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdswMonitorHomePage tab switching works with stubbed pages',
      (WidgetTester tester) async {
    // 🔹 테스트용 윈도우 사이즈를 넓게 잡아줘서 Row가 안 넘치게 함
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 전역 변수 최소 세팅 (dispose에서 rosKeeper.stop() 호출해도 죽지 않게)
    appConfig = AppConfig.defaults();
    rosKeeper = RosKeeper(appConfig);

    await tester.pumpWidget(
      MaterialApp(
        home: AdswMonitorHomePage(
          title: 'Test Home',
          adswPageBuilder: () => const FakeAdswViewPage(),
          mwPageBuilder: () => const FakeMwViewPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 처음에는 AD SW Info 탭이 보여야 함
    expect(find.byKey(const Key('FakeAdswViewPage')), findsOneWidget);
    expect(find.byKey(const Key('FakeMwViewPage')), findsNothing);

    expect(find.text('AD SW Info'), findsOneWidget);
    expect(find.text('Diagnostic Info'), findsOneWidget);

    // Diagnostic 탭 누르기
    await tester.tap(find.text('Diagnostic Info'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('FakeAdswViewPage')), findsNothing);
    expect(find.byKey(const Key('FakeMwViewPage')), findsOneWidget);
  });

  test('startRosWithUri creates AppConfig, RosKeeper and registers Ros (put case)',
      () async {
    final uri = Uri.parse('ws://example.com:1234');
    final mockRos = MockRos();
    TestRosKeeper? createdKeeper;

    await startRosWithUri(
      uri,
      keeperFactory: (cfg) {
        // AppConfig 값이 올바르게 들어오는지 검증
        expect(cfg.rosUrl, uri);
        expect(cfg.statusTopic, '/app_status/adsw_monitor');

        createdKeeper = TestRosKeeper(cfg, mockRos);
        return createdKeeper!;
      },
    );

    // 전역 appConfig / rosKeeper가 우리가 만든 걸로 설정됐는지
    expect(appConfig.rosUrl, uri);
    expect(appConfig.statusTopic, '/app_status/adsw_monitor');
    expect(rosKeeper, same(createdKeeper));

    // start()가 호출됐는지
    expect(createdKeeper!.startCalled, isTrue);

    // GetX에 Ros가 등록됐는지 (put 경로)
    expect(Get.isRegistered<Ros>(), isTrue);
    expect(Get.find<Ros>(), same(mockRos));
  });

  test('startRosWithUri replaces existing Ros in Get (replace case)', () async {
    final oldRos = MockRos();
    final newRos = MockRos();
    TestRosKeeper? createdKeeper;

    // 기존 Ros 미리 등록
    Get.put<Ros>(oldRos, permanent: true);
    expect(Get.find<Ros>(), same(oldRos));

    final uri = Uri.parse('ws://another-host:5678');

    await startRosWithUri(
      uri,
      keeperFactory: (cfg) {
        createdKeeper = TestRosKeeper(cfg, newRos);
        return createdKeeper!;
      },
    );

    // replace가 잘 됐는지: 이제는 newRos가 들어 있음
    expect(Get.isRegistered<Ros>(), isTrue);
    expect(Get.find<Ros>(), same(newRos));

    // 여전히 start는 호출되어야 함
    expect(createdKeeper!.startCalled, isTrue);
  });
}



// void main() {
//   setUp(() {
//     Get.reset();
//   });

//   test('startRosWithUri creates AppConfig, RosKeeper and registers Ros (put case)',
//       () async {
//     final uri = Uri.parse('ws://example.com:1234');
//     final mockRos = MockRos();
//     TestRosKeeper? createdKeeper;

//     await startRosWithUri(
//       uri,
//       keeperFactory: (cfg) {
//         // AppConfig 값이 올바르게 들어오는지 검증
//         expect(cfg.rosUrl, uri);
//         expect(cfg.statusTopic, '/app_status/adsw_monitor');

//         createdKeeper = TestRosKeeper(cfg, mockRos);
//         return createdKeeper!;
//       },
//     );

//     // 전역 appConfig / rosKeeper가 우리가 만든 걸로 설정됐는지
//     expect(appConfig.rosUrl, uri);
//     expect(appConfig.statusTopic, '/app_status/adsw_monitor');
//     expect(rosKeeper, same(createdKeeper));

//     // start()가 호출됐는지
//     expect(createdKeeper!.startCalled, isTrue);

//     // GetX에 Ros가 등록됐는지 (put 경로)
//     expect(Get.isRegistered<Ros>(), isTrue);
//     expect(Get.find<Ros>(), same(mockRos));
//   });

//   test('startRosWithUri replaces existing Ros in Get (replace case)', () async {
//     final oldRos = MockRos();
//     final newRos = MockRos();
//     TestRosKeeper? createdKeeper;

//     // 기존 Ros 미리 등록
//     Get.put<Ros>(oldRos, permanent: true);
//     expect(Get.find<Ros>(), same(oldRos));

//     final uri = Uri.parse('ws://another-host:5678');

//     await startRosWithUri(
//       uri,
//       keeperFactory: (cfg) {
//         createdKeeper = TestRosKeeper(cfg, newRos);
//         return createdKeeper!;
//       },
//     );

//     // replace가 잘 됐는지: 이제는 newRos가 들어 있음
//     expect(Get.isRegistered<Ros>(), isTrue);
//     expect(Get.find<Ros>(), same(newRos));

//     // 여전히 start는 호출되어야 함
//     expect(createdKeeper!.startCalled, isTrue);
//   });
// }
