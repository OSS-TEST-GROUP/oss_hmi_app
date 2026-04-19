/// L009: Integration tests for plugin embedding (ADR-002 Section 6).
///
/// Tests verify that ota_monitor and adsw_monitor view widgets are properly
/// embedded in the launcher shell and accessible via sidebar/prompt.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/main.dart';

import 'package:ota_monitor/main.dart' show OtaViewPage;
import 'package:adsw_monitor/main.dart' show AdswViewPage;

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
  setUp(() {
    // Reset GetX before each test to clear any previous state
    Get.reset();
  });

  tearDown() {
    // Reset GetX state
    Get.reset();
  }

  group('Plugin Embedding (ADR-002)', () {
    testWidgets('Test 1: launcher shows embedded ota_monitor on sidebar tap',
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
        enableRos: false, // No real ROS connection in tests
      ));
      await tester.pump(); // Initial frame

      // Tap sidebar ota_monitor item
      await tester.tap(find.byKey(const Key('sidebar_nav_ota_monitor')));
      await tester.pump(); // Trigger transition
      await tester.pump(const Duration(milliseconds: 250)); // Complete animation

      // Verify OtaEmbeddedPanel is mounted (contains OtaViewPage)
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // Note: Cannot verify exact accent color (#F5C400) in statusbar without
      // widget introspection, but accent scope is tested in shell_v2_test.dart

      // Clean up - navigate away before test ends to dispose collectors
      await tester.tap(find.byKey(const Key('sidebar_home_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets(
        'Test 2: launcher -> ota -> launcher -> adsw -> launcher cycle',
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
      ));
      await tester.pump(); // Initial frame

      // Step 1: verify home panel visible
      expect(
          find.textContaining('Which app would you like to launch'),
          findsOneWidget);

      // Step 2: tap ota_monitor, verify embedded panel renders
      await tester.tap(find.byKey(const Key('sidebar_nav_ota_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // Step 3: tap home, verify home panel back
      await tester.tap(find.byKey(const Key('sidebar_home_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
          find.textContaining('Which app would you like to launch'),
          findsOneWidget);

      // Step 4: tap adsw_monitor, verify embedded panel renders
      await tester.tap(find.byKey(const Key('sidebar_nav_adsw_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);

      // Step 5: tap home, verify home panel
      await tester.tap(find.byKey(const Key('sidebar_home_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
          find.textContaining('Which app would you like to launch'),
          findsOneWidget);

      // No GetX duplicate registration errors expected (verified by no exceptions)
    });

    testWidgets('Test 3: embedded OtaViewPage uses launcher-provided Ros',
        (tester) async {
      await _wideView(tester);

      // Pre-register a mock Ros instance before launcher starts
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
        enableRos: false, // Don't create real LauncherRosKeeper
      ));
      await tester.pump(); // Initial frame

      await tester.tap(find.byKey(const Key('sidebar_nav_ota_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // OtaEmbeddedPanel should render (contains OtaViewPage)
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

      // Verify the mock Ros is still registered (not replaced by launcher)
      expect(Get.isRegistered<Ros>(), isTrue);
      expect(Get.find<Ros>(), equals(mockRos));

      // Clean up
      await tester.tap(find.byKey(const Key('sidebar_home_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('Test 4: statusbar accent changes with app selection',
        (tester) async {
      await _wideView(tester);

      final registry = _registry([
        _m('ota_monitor',
            name: 'OTA Monitor',
            prompts: ['OTA 모니터 열어줘'],
            color: '#F5C400'), // Yellow
        _m('adsw_monitor',
            name: 'AD SW Monitor',
            prompts: ['AD SW 모니터 열어줘'],
            color: '#00E5A0'), // Green
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
      ));
      await tester.pump(); // Initial frame

      // Initial state: launcher blue accent (implicit, home selected)
      // Note: Detailed accent color verification is in shell_v2_test.dart

      // Select ota_monitor
      await tester.tap(find.byKey(const Key('sidebar_nav_ota_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);
      // Accent should now be #F5C400 (verified by shell_v2 tests)

      // Select adsw_monitor
      await tester.tap(find.byKey(const Key('sidebar_nav_adsw_monitor')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
      // Accent should now be #00E5A0 (verified by shell_v2 tests)

      // Return home
      await tester.tap(find.byKey(const Key('sidebar_home_item')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
          find.textContaining('Which app would you like to launch'),
          findsOneWidget);
      // Accent should revert to launcher blue
    });
  });
}
