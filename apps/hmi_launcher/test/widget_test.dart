// E2E widget tests for the Tesla-reskin launcher shell.
//
// Coverage here is scoped to shell-level behavior: registry → sidebar
// rendering, prompt → plugin launch, sidebar tap → embedded panel,
// and the Launcher / plugin / Launcher cycle. Plugin-internal coverage
// lives in each plugin's own test suite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/presentation/shell/launcher_shell.dart';

PluginRegistry _registry(List<AppManifest> apps) {
  return PluginRegistry(
    List.unmodifiable(apps.map((m) => RegistryEntry.ok(m))),
  );
}

AppManifest _m(
  String id, {
  required List<String> prompts,
  String? name,
  String color = '#FCD34D',
}) =>
    AppManifest(
      id: id,
      name: name ?? id,
      icon: '📦',
      version: '1.0.0',
      entry: '$id/main.dart',
      prompts: prompts,
      color: color,
    );

/// Panel factory for tests: mount a tiny, self-contained widget instead
/// of the real OTA / ADSW plugin panels so shell-level routing can be
/// exercised without pulling in plugin collectors and timers.
Widget _placeholderPanel(AppManifest app) {
  return Center(
    key: Key('stub_panel_${app.id}'),
    child: Text('stub ${app.name}'),
  );
}

Future<void> _wideView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  tearDown(() {
    Get.reset();
  });

  testWidgets('renders the launcher shell with sidebar entries from registry',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
      _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    expect(find.byType(LauncherShell), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_home')), findsOneWidget);

    // Home header greeting and app-count line.
    expect(find.text('Good afternoon'), findsOneWidget);
    expect(find.textContaining('2 apps installed'), findsWidgets);
  });

  testWidgets('typing a matching prompt launches the embedded plugin',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'OTA 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('short app-name query also routes via the name fallback',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['업데이트 상태']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'ota',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('non-matching input surfaces a helpful toast and no launch',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      '오늘 날씨 어때',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('try:'), findsOneWidget);
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('close command returns to the home panel',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    // Open via sidebar.
    await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

    // Submit "close" — should return to the home panel.
    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'close',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsNothing);
    expect(find.text('Good afternoon'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('sidebar tap selects the app and shows the embedded panel',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
      _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    await tester.tap(find.byKey(const Key('sidebar_item_adsw_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
  });

  testWidgets('empty registry renders the shell with the home item only',
      (tester) async {
    await _wideView(tester);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: _registry(const []),
      enableRos: false,
    ));

    expect(find.byType(LauncherShell), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_home')), findsOneWidget);
    expect(find.textContaining('0 apps installed'), findsWidgets);
  });

  // ───────────────────────────────────────────────────────────────────────
  // L007 regression: sidebar + prompt routes both apps without mixing
  // state, and navigating home from a plugin returns to the launcher
  // home panel.
  // ───────────────────────────────────────────────────────────────────────

  testWidgets(
      'L007 E2E — two apps: sidebar + prompt route correctly with no cross-activation',
      (tester) async {
    await _wideView(tester);
    final ota = _m(
      'ota_monitor',
      name: 'OTA Monitor',
      prompts: ['OTA 모니터 열어줘', '버전 확인해줘'],
      color: '#FCD34D',
    );
    final adsw = _m(
      'adsw_monitor',
      name: 'AD SW',
      prompts: ['AD SW 모니터 열어줘', '센서 상태 보여줘'],
      color: '#7FE5A1',
    );
    final registry = _registry([ota, adsw]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
    ));

    // 1. sidebar shows both plugin items
    expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);

    // 2. prompt "AD SW 모니터 열어줘" launches adsw and leaves ota alone
    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'AD SW 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsNothing);

    // 3. prompt "OTA 모니터 열어줘" swaps to ota, dismissing adsw
    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'OTA 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsNothing);

    await tester.pumpAndSettle();

    // 4. tapping the home item returns to the home panel
    await tester.tap(find.byKey(const Key('sidebar_item_home')));
    await tester.pumpAndSettle();
    expect(find.text('Good afternoon'), findsOneWidget);

    // 5. tapping the adsw sidebar item mounts its embedded panel again
    await tester.tap(find.byKey(const Key('sidebar_item_adsw_monitor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
  });
}
