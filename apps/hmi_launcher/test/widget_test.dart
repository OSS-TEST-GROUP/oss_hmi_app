// E2E widget tests for the launcher main shell.
//
// The previous L002 placeholder tests are subsumed by:
//   - tests in this file (main shell + prompt → card flow)
//   - test/widgets_test.dart (individual widgets)
//   - test/plugin_registry_test.dart (domain)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/presentation/layout/four_zone_layout.dart';

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

Future<void> _wideView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders the four zones and sidebar entries from registry',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
      _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(initialRegistry: registry));

    expect(find.byType(FourZoneLayout), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);
    expect(find.text('어떤 앱을 실행할까요?'), findsOneWidget);
  });

  testWidgets('typing a matching prompt shows the AppLaunchCard',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(initialRegistry: registry));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'OTA 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsOneWidget);
    expect(find.text('OTA Monitor'), findsWidgets);
  });

  testWidgets('non-matching input shows a helpful message and no card',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(initialRegistry: registry));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      '오늘 날씨 어때',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byKey(const Key('main_message')), findsOneWidget);
    expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsNothing);
  });

  testWidgets('sidebar tap selects the app and surfaces its card',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
      _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(initialRegistry: registry));

    await tester.tap(find.byKey(const Key('sidebar_item_adsw_monitor')));
    await tester.pump();

    expect(find.byKey(const Key('app_launch_card_adsw_monitor')), findsOneWidget);
  });

  testWidgets('empty registry renders an instructional empty state',
      (tester) async {
    await _wideView(tester);
    await tester.pumpWidget(HmiLauncherApp(initialRegistry: _registry(const [])));

    expect(find.textContaining('등록된 앱이 없습니다'), findsOneWidget);
  });
}
