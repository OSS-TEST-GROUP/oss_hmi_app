// QA(docs/qa): LauncherHomePanel 위젯 테스트 (apps 그리드 + Recent/Suggested aside).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/presentation/panels/launcher_home_panel.dart';

AppManifest _m(String id) => AppManifest(
      id: id,
      name: id,
      icon: '📦',
      version: '1.0.0',
      entry: '$id/main.dart',
      prompts: const [],
    );

void main() {
  Future<void> pumpPanel(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('apps + aside 렌더 + greeting', (tester) async {
    final launched = <String>[];
    await pumpPanel(
      tester,
      LauncherHomePanel(
        apps: [_m('ota_monitor'), _m('adsw_monitor'), _m('lfc_monitor')],
        onAppLaunch: (a) => launched.add(a.id),
        recent: const [
          HomeAsideItem(appId: 'ota_monitor', name: 'OTA', meta: '방금'),
        ],
        suggestions: const [
          HomeAsideItem(appId: 'adsw_monitor', name: 'AD SW', meta: '자주 씀'),
        ],
        greeting: '안녕하세요',
      ),
    );
    expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
    expect(find.text('안녕하세요'), findsWidgets);
    expect(find.text('ota_monitor'), findsWidgets);
  });

  testWidgets('앱 카드 탭 → onAppLaunch 콜백', (tester) async {
    final launched = <String>[];
    await pumpPanel(
      tester,
      LauncherHomePanel(
        apps: [_m('ota_monitor')],
        onAppLaunch: (a) => launched.add(a.id),
        recent: const [],
        suggestions: const [],
        greeting: 'hi',
      ),
    );
    await tester.tap(find.text('ota_monitor').first, warnIfMissed: false);
    await tester.pump();
    expect(launched, contains('ota_monitor'));
  });

  testWidgets('빈 리스트도 크래시 없이 렌더', (tester) async {
    await pumpPanel(
      tester,
      LauncherHomePanel(
        apps: const [],
        onAppLaunch: (_) {},
        recent: const [],
        suggestions: const [],
        greeting: 'hi',
      ),
    );
    expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
  });

  test('HomeAsideItem 필드', () {
    const item = HomeAsideItem(
      appId: 'x', name: 'X', meta: 'm', icon: Icons.star,
    );
    expect(item.appId, 'x');
    expect(item.name, 'X');
    expect(item.icon, Icons.star);
  });
}
