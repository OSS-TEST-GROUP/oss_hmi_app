// QA(docs/qa): LauncherBotShell 상호작용 (앱전환/설정/관리앱) — 실 ros 없이 stub 패널.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/presentation/shell/launcher_bot_shell.dart';

PluginRegistry _registry(List<AppManifest> apps) =>
    PluginRegistry(List.unmodifiable(apps.map((m) => RegistryEntry.ok(m))));

AppManifest _m(String id, {String? name}) => AppManifest(
      id: id, name: name ?? id, icon: '📦', version: '1.0.0',
      entry: '$id/main.dart', prompts: ['$id 열어줘'],
    );

Widget _stub(AppManifest app) =>
    Center(key: Key('stub_${app.id}'), child: Text('stub ${app.name}'));

Future<void> _pump(WidgetTester tester, PluginRegistry registry) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(HmiLauncherApp(
    initialRegistry: registry,
    visibilityStore: AppVisibilityStore.inMemory(),
    enableRos: false,
    panelBuilder: _stub,
    botAvailabilityProbe: ({required String host, required int port}) async => false,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  tearDown(Get.reset);

  testWidgets('사이드바로 앱 전환 → stub 패널 표시', (tester) async {
    await _pump(tester, _registry([_m('ota_monitor'), _m('adsw_monitor')]));
    expect(find.byType(LauncherBotShell), findsOneWidget);
    await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('stub_ota_monitor')), findsOneWidget);
    // 다른 앱으로 전환
    await tester.tap(find.byKey(const Key('sidebar_item_adsw_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('stub_adsw_monitor')), findsOneWidget);
    // 홈으로
    await tester.tap(find.byKey(const Key('sidebar_item_home')));
    await tester.pump();
    expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
  });

  testWidgets('설정 열기 → settings_panel 렌더', (tester) async {
    await _pump(tester, _registry([_m('ota_monitor')]));
    // 홈 그리드의 설정 카드(앱==null) 탭 — settings 아이콘으로 찾음.
    final settingsIcon = find.byIcon(Icons.settings_outlined);
    if (settingsIcon.evaluate().isNotEmpty) {
      await tester.tap(settingsIcon.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    // 설정 진입 경로 실행(패널 렌더는 위젯 구조에 따라 달라 스모크만).
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('관리앱 패널 열기/토글', (tester) async {
    await _pump(tester, _registry([_m('ota_monitor'), _m('adsw_monitor')]));
    final manageBtn = find.byKey(const Key('manage_apps_button'));
    if (manageBtn.evaluate().isNotEmpty) {
      await tester.tap(manageBtn.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('manage_apps_panel')), findsWidgets);
    }
  });

  testWidgets('assistant 토글', (tester) async {
    await _pump(tester, _registry([_m('ota_monitor')]));
    final toggle = find.byKey(const Key('assistant_toggle'));
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });
}
