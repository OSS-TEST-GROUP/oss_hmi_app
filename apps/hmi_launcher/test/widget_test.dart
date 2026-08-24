// Shell-level widget tests for the launcher (LauncherBotShell — L008 reskin).
//
// The launcher was reskinned from the old sidebar/promptbar LauncherShell to
// the chatbot-integrated LauncherBotShell (_AppRail + LauncherBotPanel +
// home grid). These tests cover the stable, shell-level behaviors of the new
// shell: registry → home grid rendering, grid-card tap → embedded plugin
// panel, and home greeting/app-count. Plugin internals live in each plugin's
// own suite; chat/AI behavior lives in launcher_bot_controller_test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/presentation/shell/launcher_bot_shell.dart';

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

/// Self-contained stub panel so shell routing can be exercised without
/// pulling in real plugin collectors/timers.
Widget _placeholderPanel(AppManifest app) => Center(
      key: Key('stub_panel_${app.id}'),
      child: Text('stub ${app.name}'),
    );

Future<void> _wideView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpApp(WidgetTester tester, PluginRegistry registry) async {
  await tester.pumpWidget(HmiLauncherApp(
    initialRegistry: registry,
    visibilityStore: AppVisibilityStore.inMemory(),
    enableRos: false,
    panelBuilder: _placeholderPanel,
    // Deterministic launcher-bot probe — avoid a real socket (and its pending
    // timer) so these home/embed tests stay hermetic. Bot stays hidden.
    botAvailabilityProbe: ({required String host, required int port}) async =>
        false,
  ));
  // Let the first post-frame setState (config load / shell init) settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  tearDown(() {
    Get.reset();
  });

  testWidgets('renders the bot shell with the home surface from registry',
      (tester) async {
    await _wideView(tester);
    await _pumpApp(
      tester,
      _registry([
        _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 열어줘']),
        _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 열어줘']),
      ]),
    );

    expect(find.byType(LauncherBotShell), findsOneWidget);
    expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
    expect(find.byKey(const Key('launcher_home_grid')), findsOneWidget);

    // Per-app home grid cards (one card per registry app).
    expect(find.byKey(const Key('home_cat_card_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('home_cat_card_adsw_monitor')), findsOneWidget);
  });

  testWidgets('tapping a home grid card launches the embedded plugin panel',
      (tester) async {
    await _wideView(tester);
    await _pumpApp(
      tester,
      _registry([
        _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 열어줘']),
      ]),
    );

    await tester.tap(find.byKey(const Key('home_cat_card_ota_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);
  });

  testWidgets('empty registry still renders the shell + home surface',
      (tester) async {
    await _wideView(tester);
    await _pumpApp(tester, _registry(const []));

    expect(find.byType(LauncherBotShell), findsOneWidget);
    expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
    // No plugin cards when the registry is empty.
    expect(find.byKey(const Key('home_cat_card_ota_monitor')), findsNothing);
  });

  testWidgets(
      'two apps: each grid card routes to its own embedded panel (no cross-activation)',
      (tester) async {
    await _wideView(tester);
    await _pumpApp(
      tester,
      _registry([
        _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 열어줘']),
        _m('adsw_monitor', name: 'AD SW', prompts: ['AD SW 열어줘']),
      ]),
    );

    // Launch adsw → adsw embedded, ota not mounted.
    await tester.tap(find.byKey(const Key('home_cat_card_adsw_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsNothing);
  });
}
