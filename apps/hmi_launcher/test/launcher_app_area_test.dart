// QA(docs/qa): LauncherAppArea — home/placeholder/injected-panel 라우팅.
// 실제 embedded 패널(ota/adsw/lfc/rviz2/vehicle)은 백그라운드 타이머 때문에
// 통합 경계로 분류 → 여기서는 home(null 선택), 미지원 앱(default→placeholder),
// panelBuilder 주입 분기만 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/presentation/shell/launcher_app_area.dart';
import 'package:hmi_launcher/presentation/theme/app_accent_scope.dart';

AppManifest _m(String id, {String? name}) => AppManifest(
      id: id, name: name ?? id, icon: '📦', version: '1.0.0',
      entry: '$id/main.dart', prompts: const [],
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: AppAccentScope(
      accentColor: const Color(0xFF6366F1),
      child: Scaffold(body: child),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('selectedAppId=null → home panel', (tester) async {
    await _pump(
      tester,
      LauncherAppArea(
        apps: [_m('ota_monitor')],
        selectedAppId: null,
        onAppLaunch: (_) {},
      ),
    );
    expect(find.byKey(const Key('launcher_app_area')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_panel')), findsOneWidget);
  });

  testWidgets('미지원 앱 → AppPlaceholderPanel(default 분기)', (tester) async {
    await _pump(
      tester,
      LauncherAppArea(
        apps: [_m('future_app', name: 'Future')],
        selectedAppId: 'future_app',
        onAppLaunch: (_) {},
      ),
    );
    expect(find.byKey(const Key('app_placeholder_future_app')), findsOneWidget);
    expect(find.text('Future is being prepared'), findsOneWidget);
  });

  testWidgets('panelBuilder 주입 시 주입 위젯 사용', (tester) async {
    await _pump(
      tester,
      LauncherAppArea(
        apps: [_m('ota_monitor')],
        selectedAppId: 'ota_monitor',
        onAppLaunch: (_) {},
        panelBuilder: (app) =>
            Center(key: Key('injected_${app.id}'), child: Text(app.name)),
      ),
    );
    expect(find.byKey(const Key('injected_ota_monitor')), findsOneWidget);
  });
}
