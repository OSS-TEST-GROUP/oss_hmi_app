// Integration tests for plugin embedding (ADR-002) on the LauncherBotShell.
//
// Verifies that plugin panels mount inside the launcher shell on launch
// (home grid card / app rail), survive round-trips through the home surface,
// and that an externally-registered Ros owned by the launcher is not clobbered
// when a plugin panel mounts. (Reskin L008: launch = home grid card; nav = app
// rail items addressed by tooltip; home surface = launcher_home_panel.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/main.dart';

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
    enableRos: false,
    panelBuilder: _placeholderPanel,
    // Deterministic launcher-bot probe — no real socket / pending timer.
    botAvailabilityProbe: ({required String host, required int port}) async =>
        false,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  setUp(Get.reset);
  tearDown(Get.reset);

  group('Plugin Embedding (ADR-002)', () {
    final twoApps = [
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 열어줘'], color: '#F5C400'),
      _m('adsw_monitor', name: 'AD SW Monitor', prompts: ['AD SW 열어줘'], color: '#00E5A0'),
    ];

    testWidgets('Test 1: home grid card shows the embedded ota_monitor panel',
        (tester) async {
      await _wideView(tester);
      await _pumpApp(tester, _registry(twoApps));

      await tester.tap(find.byKey(const Key('home_cat_card_ota_monitor')));
      await _settle(tester);
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // Home rail returns to the home surface.
      await tester.tap(find.byTooltip('Home'));
      await _settle(tester);
      expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
    });

    testWidgets(
        'Test 2: home → ota → home → adsw → home cycle keeps the shell stable',
        (tester) async {
      await _wideView(tester);
      await _pumpApp(tester, _registry(twoApps));

      // Home visible on launch.
      expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);

      // Home → ota (grid card)
      await tester.tap(find.byKey(const Key('home_cat_card_ota_monitor')));
      await _settle(tester);
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // ota → home (rail)
      await tester.tap(find.byTooltip('Home'));
      await _settle(tester);
      expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);

      // home → adsw (grid card)
      await tester.tap(find.byKey(const Key('home_cat_card_adsw_monitor')));
      await _settle(tester);
      expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);

      // adsw → home (rail)
      await tester.tap(find.byTooltip('Home'));
      await _settle(tester);
      expect(find.byKey(const Key('launcher_home_panel')), findsOneWidget);
    });

    testWidgets('Test 3: externally registered Ros survives a plugin mount',
        (tester) async {
      await _wideView(tester);

      // A test harness may inject its own mock Ros before the launcher
      // mounts. The launcher must not stomp on it when enableRos=false.
      final mockRos = Ros(url: 'ws://fake:9090');
      Get.put<Ros>(mockRos);

      await _pumpApp(
        tester,
        _registry([twoApps.first]),
      );

      await tester.tap(find.byKey(const Key('home_cat_card_ota_monitor')));
      await _settle(tester);

      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);
      expect(Get.isRegistered<Ros>(), isTrue);
      // Identity check — equals() would force Ros.hashCode which touches its
      // uninitialised _channel on a never-connected mock.
      expect(identical(Get.find<Ros>(), mockRos), isTrue);
    });
  });
}
