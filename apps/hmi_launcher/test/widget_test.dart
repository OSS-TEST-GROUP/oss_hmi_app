// E2E widget tests for the launcher main shell.
//
// The previous L002 placeholder tests are subsumed by:
//   - tests in this file (main shell + prompt → card flow)
//   - test/widgets_test.dart (individual widgets)
//   - test/plugin_registry_test.dart (domain)
//
// Migrated to LauncherShell (L008) — no longer uses FourZoneLayout.

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

Future<void> _wideView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  tearDown(() {
    // Clean up GetX state
    Get.reset();
  });

  testWidgets('renders the launcher shell and sidebar entries from registry',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
      _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false, // L009: disable ROS in tests
    ));

    expect(find.byType(LauncherShell), findsOneWidget);
    expect(find.byKey(const Key('sidebar_nav_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_nav_adsw_monitor')), findsOneWidget);
    expect(find.textContaining('Which app would you like to launch'), findsOneWidget);
  });

  testWidgets('typing a matching prompt shows the AppLaunchCard',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false, // L009: disable ROS in tests
    ));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'OTA 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Wait for scroll animation to complete
    await tester.pump(const Duration(milliseconds: 300));

    // Card should appear before auto-launch (which happens at 320ms)
    expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsOneWidget);
    expect(find.text('OTA Monitor'), findsWidgets);

    // Complete pending timers before test ends
    await tester.pumpAndSettle();
  });

  testWidgets('non-matching input shows a helpful message and no card',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false, // L009: disable ROS in tests
    ));

    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      '오늘 날씨 어때',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('No matching app found'), findsOneWidget);
    expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsNothing);
  });

  testWidgets('sidebar tap selects the app and shows embedded panel',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
      _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false, // L009: disable ROS in tests
    ));

    await tester.tap(find.byKey(const Key('sidebar_nav_adsw_monitor')));
    await tester.pump();

    // L009: sidebar tap shows embedded panel, not placeholder
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
  });

  testWidgets('empty registry renders launcher shell with no app items',
      (tester) async {
    await _wideView(tester);
    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: _registry(const []),
      enableRos: false, // L009: disable ROS in tests
    ));

    // LauncherShell should render
    expect(find.byType(LauncherShell), findsOneWidget);

    // Home panel should render with initial message
    expect(find.textContaining('Which app would you like to launch'), findsOneWidget);

    // No app nav items (only home item exists)
    expect(find.byKey(const Key('sidebar_home_item')), findsOneWidget);
  });

  // ──────────────────────────────────────────────────────────────────────
  // L007 E2E — both ota_monitor and adsw_monitor are reachable through
  // the sidebar and the prompt, and activating one does not regress the
  // other (key regression guard for L006 + L007 together).
  // ──────────────────────────────────────────────────────────────────────

  testWidgets(
      'L007 E2E — two apps: sidebar + prompt both route correctly and no cross-activation',
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
      enableRos: false, // L009: disable ROS in tests
    ));

    // 1. sidebar shows both apps
    expect(find.byKey(const Key('sidebar_nav_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_nav_adsw_monitor')), findsOneWidget);

    // 2. prompt 'AD SW 모니터 열어줘' → adsw card (in home panel)
    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'AD SW 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app_launch_card_adsw_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsNothing);

    // 3. prompt 'OTA 모니터 열어줘' → ota card (adsw card gone)
    await tester.enterText(
      find.byKey(const Key('prompt_input_field')),
      'OTA 모니터 열어줘',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_launch_card_adsw_monitor')), findsNothing);

    // Wait for auto-launch timer to complete
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // 4. tapping home returns to launcher home panel
    await tester.tap(find.byKey(const Key('sidebar_home_item')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Which app would you like to launch'), findsOneWidget);

    // 5. tapping adsw sidebar item navigates to embedded panel (L009)
    await tester.tap(find.byKey(const Key('sidebar_nav_adsw_monitor')));
    await tester.pumpAndSettle();
    // L009: now shows embedded AdswEmbeddedPanel instead of placeholder
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
  });
}
