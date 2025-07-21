import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:mocktail/mocktail.dart';

// Stub 페이지들
class FakeAdswViewPage extends StatelessWidget {
  const FakeAdswViewPage({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('FakeAdswViewPage'));
}

class FakeMwViewPage extends StatelessWidget {
  const FakeMwViewPage({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('FakeMwViewPage'));
}

// AdswMonitorHomePage의 탭 전환 기능만 재현해둔 테스트용 페이지
class TestableHomePage extends StatelessWidget {
  final Ros ros;
  const TestableHomePage({super.key, required this.ros});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: const [
              TabBar(
                tabs: [
                  Tab(text: 'AD SW Info'),
                  Tab(text: 'Diagnostic Info'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    FakeAdswViewPage(),
                    FakeMwViewPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MockRos extends Mock implements Ros {}

void main() {
  testWidgets('Tab switching works with stubbed pages', (WidgetTester tester) async {
    final ros = MockRos();

    await tester.pumpWidget(TestableHomePage(ros: ros));

    // AD SW Info is visible initially
    expect(find.byKey(const Key('FakeAdswViewPage')), findsOneWidget);
    expect(find.byKey(const Key('FakeMwViewPage')), findsNothing);

    // Tap second tab
    await tester.tap(find.text('Diagnostic Info'));
    await tester.pumpAndSettle();

    // Diagnostic tab should now be shown
    expect(find.byKey(const Key('FakeAdswViewPage')), findsNothing);
    expect(find.byKey(const Key('FakeMwViewPage')), findsOneWidget);
  });
}
