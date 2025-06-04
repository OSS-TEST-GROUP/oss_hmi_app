import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/main.dart';
import 'package:adsw_monitor/view/adsw_view_page.dart';
import 'package:adsw_monitor/view/mw_view_page.dart';

void main() {
  testWidgets('AdswMonitorApp renders and switches tabs correctly', (WidgetTester tester) async {
    // 앱 구동
    await tester.pumpWidget(const AdswMonitorApp());

    // 초기 화면에 TabBar와 첫 탭 텍스트가 보여야 함
    expect(find.text('AD SW Info'), findsOneWidget);
    expect(find.text('Diagnostic Info'), findsOneWidget);

    // 기본 첫 번째 탭은 AdswViewPage 인스턴스가 표시되어야 함
    expect(find.byType(AdswViewPage), findsOneWidget);
    expect(find.byType(MwViewPage), findsNothing);

    // 탭을 두 번째 탭으로 변경
    await tester.tap(find.text('Diagnostic Info'));
    await tester.pumpAndSettle(); // 탭 전환 애니메이션 기다림

    // 두 번째 탭 내용이 보여야 함
    expect(find.byType(MwViewPage), findsOneWidget);
    expect(find.byType(AdswViewPage), findsNothing);

    // 다시 첫 번째 탭으로 변경
    await tester.tap(find.text('AD SW Info'));
    await tester.pumpAndSettle();

    // 첫 번째 탭 내용 다시 보여야 함
    expect(find.byType(AdswViewPage), findsOneWidget);
    expect(find.byType(MwViewPage), findsNothing);
  });
}