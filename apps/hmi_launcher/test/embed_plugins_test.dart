// L009: Integration tests for plugin embedding (ADR-002).
//
// Verifies that ota_monitor and adsw_monitor views mount inside the
// launcher shell on sidebar/prompt selection, survive round-trips
// through the home panel, and that the shared Ros instance owned by
// the launcher is not clobbered when the plugin panel mounts.
//
// Migration note (F015): HmiLauncherApp now renders LauncherBotShell.
// Sidebar items use keys 'sidebar_item_<id>' (all installed apps visible
// without opening them first).  The home panel shows a greeting widget
// with key 'home_greeting'.
//
// FallbackLauncherBotAiService is injected via HmiLauncherApp.aiService
// to avoid real gRPC connections.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/main.dart';

/// Injected in every test — no gRPC, immediate responses.
const _testAiService = FallbackLauncherBotAiService();

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

/// Test-only panel factory. Avoids pulling in OTA / ADSW internals so
/// the embed-path tests can focus on shell-level routing.
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
  setUp(Get.reset);
  tearDown(Get.reset);

  group('Plugin Embedding (ADR-002)', () {
    testWidgets('Test 1: sidebar tap shows the embedded ota_monitor panel',
        (tester) async {
      await _wideView(tester);

      final registry = _registry([
        _m('ota_monitor',
            name: 'OTA Monitor',
            prompts: ['OTA 모니터 열어줘'],
            color: '#F5C400'),
        _m('adsw_monitor',
            name: 'AD SW Monitor',
            prompts: ['AD SW 모니터 열어줘'],
            color: '#00E5A0'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: AppVisibilityStore.inMemory(),
        panelBuilder: _placeholderPanel,
        aiService: _testAiService,
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // Navigate back to home so pending timers/collectors unwind cleanly.
      await tester.tap(find.byKey(const Key('sidebar_item_home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets(
        'Test 2: home → ota → home → adsw → home cycle keeps the shell stable',
        (tester) async {
      await _wideView(tester);

      final registry = _registry([
        _m('ota_monitor',
            name: 'OTA Monitor',
            prompts: ['OTA 모니터 열어줘'],
            color: '#F5C400'),
        _m('adsw_monitor',
            name: 'AD SW Monitor',
            prompts: ['AD SW 모니터 열어줘'],
            color: '#00E5A0'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: AppVisibilityStore.inMemory(),
        panelBuilder: _placeholderPanel,
        aiService: _testAiService,
      ));
      await tester.pump();

      // Home visible on launch — greeting widget should be present.
      expect(find.byKey(const Key('home_greeting')), findsOneWidget);

      // Home → ota
      await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // ota → home
      await tester.tap(find.byKey(const Key('sidebar_item_home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('home_greeting')), findsOneWidget);

      // home → adsw
      await tester.tap(find.byKey(const Key('sidebar_item_adsw_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);

      // adsw → home
      await tester.tap(find.byKey(const Key('sidebar_item_home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('home_greeting')), findsOneWidget);
    });

    testWidgets(
        'Test 3: externally registered Ros survives a plugin mount',
        (tester) async {
      await _wideView(tester);

      // A test harness may inject its own mock Ros before the launcher
      // mounts. The launcher should not stomp on it when enableRos=false.
      final mockRos = Ros(url: 'ws://fake:9090');
      Get.put<Ros>(mockRos);

      final registry = _registry([
        _m('ota_monitor',
            name: 'OTA Monitor',
            prompts: ['OTA 모니터 열어줘'],
            color: '#F5C400'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: AppVisibilityStore.inMemory(),
        panelBuilder: _placeholderPanel,
        aiService: _testAiService,
      ));
      await tester.pump();

      await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);
      expect(Get.isRegistered<Ros>(), isTrue);
      // Identity check — equals() would force Ros.hashCode which touches
      // its uninitialised _channel on a never-connected mock.
      expect(identical(Get.find<Ros>(), mockRos), isTrue);

      await tester.tap(find.byKey(const Key('sidebar_item_home')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });
  });
}
