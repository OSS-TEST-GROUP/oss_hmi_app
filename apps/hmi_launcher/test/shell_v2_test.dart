import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/presentation/shell/launcher_shell.dart';
import 'package:hmi_launcher/presentation/theme/launcher_tokens.dart';
import 'package:hmi_launcher/presentation/theme/app_accent_scope.dart';

void main() {
  group('Shell v2 Tests (ADR-001)', () {
    late PluginRegistry testRegistry;

    setUp(() {
      // Register mock Ros for embedded panels (IndexedStack creates all panels upfront)
      Get.reset();
      Get.put<Ros>(Ros(url: 'ws://mock:9090'));

      final otaManifest = AppManifest(
        id: 'ota_monitor',
        name: 'OTA Monitor',
        icon: '📦',
        version: '1.0.0',
        entry: 'ota_monitor/main.dart',
        category: 'monitoring',
        color: '#F5C400',
        prompts: ['OTA 모니터 열어줘', 'OTA 업데이트'],
      );

      final adswManifest = AppManifest(
        id: 'adsw_monitor',
        name: 'AD SW Monitor',
        icon: '📡',
        version: '1.0.0',
        entry: 'adsw_monitor/main.dart',
        category: 'monitoring',
        color: '#00E5A0',
        prompts: ['AD SW 모니터 열어줘', 'AD 모니터'],
      );

      testRegistry = PluginRegistry([
        RegistryEntry.ok(otaManifest),
        RegistryEntry.ok(adswManifest),
      ]);
    });

    tearDown(() {
      // Clean up GetX state from embedded panels
      Get.reset();
    });

    testWidgets('Test Case A: accent color propagates when app selection changes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LauncherShell(
            registry: testRegistry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: launcher accent (cyan)
      final initialShell = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(initialShell, isNotNull);

      // Find AppAccentScope
      final initialAccentScope = tester.widget<AppAccentScope>(
        find.byType(AppAccentScope),
      );
      expect(initialAccentScope.accentColor, LauncherTokens.launcher);

      // Tap ota_monitor from sidebar
      await tester.tap(find.byKey(const Key('sidebar_nav_ota_monitor')));
      await tester.pump(); // Trigger state change
      await tester.pump(const Duration(milliseconds: 250)); // Complete animation

      // Accent should now be OTA yellow
      final otaAccentScope = tester.widget<AppAccentScope>(
        find.byType(AppAccentScope),
      );
      expect(otaAccentScope.accentColor, const Color(0xFFF5C400));

      // Tap adsw_monitor from sidebar
      await tester.tap(find.byKey(const Key('sidebar_nav_adsw_monitor')));
      await tester.pump(); // Trigger state change
      await tester.pump(const Duration(milliseconds: 250)); // Complete animation

      // Accent should now be ADSW green
      final adswAccentScope = tester.widget<AppAccentScope>(
        find.byType(AppAccentScope),
      );
      expect(adswAccentScope.accentColor, const Color(0xFF00E5A0));
    });

    testWidgets('Test Case B: sidebar renders nav-items for each registered app',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LauncherShell(
            registry: testRegistry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify home item exists
      expect(find.byKey(const Key('sidebar_home_item')), findsOneWidget);

      // Verify app nav items exist
      expect(find.byKey(const Key('sidebar_nav_ota_monitor')), findsOneWidget);
      expect(find.byKey(const Key('sidebar_nav_adsw_monitor')), findsOneWidget);

      // Verify add button and connection indicator
      expect(find.byKey(const Key('sidebar_add_button')), findsOneWidget);
      expect(find.byKey(const Key('sidebar_connection_indicator')), findsOneWidget);
    });

    testWidgets('Test Case C: quick chip click shows AppLaunchCard',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LauncherShell(
            registry: testRegistry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify quick chips exist
      expect(find.byKey(const Key('quick_chip_ota_monitor')), findsOneWidget);
      expect(find.byKey(const Key('quick_chip_adsw_monitor')), findsOneWidget);

      // Tap quick chip for ota_monitor
      await tester.tap(find.byKey(const Key('quick_chip_ota_monitor')));
      await tester.pumpAndSettle();

      // AppLaunchCard should appear in the home panel
      expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsOneWidget);
      expect(find.byKey(const Key('app_launch_button_ota_monitor')), findsOneWidget);
    });

    testWidgets('Test Case D: prompt input matching app shows AppLaunchCard',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LauncherShell(
            registry: testRegistry,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter text in prompt input
      await tester.enterText(
        find.byKey(const Key('prompt_input_field')),
        'OTA 모니터 열어줘',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Wait for scroll animation
      await tester.pump(const Duration(milliseconds: 300));

      // User bubble should appear
      expect(find.byKey(const Key('chat_bubble_user')), findsAtLeastNWidgets(1));

      // AppLaunchCard should appear before auto-launch
      expect(find.byKey(const Key('app_launch_card_ota_monitor')), findsOneWidget);

      // Complete pending timers
      await tester.pumpAndSettle();
    });
  });
}
