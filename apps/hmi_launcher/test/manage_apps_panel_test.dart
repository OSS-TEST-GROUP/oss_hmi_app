// F017 AC3: ManageAppsPanel widget tests.
//
// AC3: "Manage Apps" panel opens from the top-bar grid icon, lists all
//      discovered apps with toggle switches, and toggling immediately
//      updates the sidebar/home.
//
// AC2 (filter): verified here by toggling a switch and checking the
//      visibility store and sidebar are updated accordingly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/presentation/panels/manage_apps_panel.dart';

const _testAiService = FallbackLauncherBotAiService();

AppManifest _m(String id, {String name = ''}) => AppManifest(
      id: id,
      name: name.isEmpty ? id : name,
      icon: '📦',
      version: '1.0.0',
      entry: '$id/main.dart',
      prompts: const [],
      color: '#FCD34D',
    );

PluginRegistry _registry(List<AppManifest> apps) => PluginRegistry(
      List.unmodifiable(apps.map((m) => RegistryEntry.ok(m))),
    );

Future<void> _wideView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  tearDown(Get.reset);

  // ── ManageAppsPanel unit widget tests ──────────────────────────────────

  group('ManageAppsPanel unit', () {
    testWidgets('renders manage_apps_panel key', (tester) async {
      final store = AppVisibilityStore.inMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: [_m('ota_monitor', name: 'OTA Monitor')],
            store: store,
            onClose: () {},
          ),
        ),
      ));

      expect(find.byKey(const Key('manage_apps_panel')), findsOneWidget);
    });

    testWidgets('lists toggle for each app with key manage_toggle_<id>',
        (tester) async {
      final apps = [
        _m('ota_monitor', name: 'OTA Monitor'),
        _m('adsw_monitor', name: 'AD SW'),
        _m('lfc_monitor', name: 'LFC Monitor'),
      ];
      final store = AppVisibilityStore.inMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: apps,
            store: store,
            onClose: () {},
          ),
        ),
      ));

      for (final app in apps) {
        expect(find.byKey(Key('manage_toggle_${app.id}')), findsOneWidget);
      }
    });

    testWidgets('toggle switch starts in ON state for enabled apps',
        (tester) async {
      final store = AppVisibilityStore.inMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: [_m('ota_monitor')],
            store: store,
            onClose: () {},
          ),
        ),
      ));

      final sw = tester
          .widget<Switch>(find.byKey(const Key('manage_toggle_ota_monitor')));
      expect(sw.value, isTrue);
    });

    testWidgets('toggle switch starts in OFF state for disabled app',
        (tester) async {
      final store =
          AppVisibilityStore.inMemory(initialDisabled: {'adsw_monitor'});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: [_m('adsw_monitor')],
            store: store,
            onClose: () {},
          ),
        ),
      ));

      final sw = tester.widget<Switch>(
          find.byKey(const Key('manage_toggle_adsw_monitor')));
      expect(sw.value, isFalse);
    });

    testWidgets('tapping toggle disables an enabled app (AC3)', (tester) async {
      final store = AppVisibilityStore.inMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: [_m('ota_monitor')],
            store: store,
            onClose: () {},
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('manage_toggle_ota_monitor')));
      await tester.pump();

      expect(store.isEnabled('ota_monitor'), isFalse);
      final sw = tester.widget<Switch>(
          find.byKey(const Key('manage_toggle_ota_monitor')));
      expect(sw.value, isFalse);
    });

    testWidgets('tapping toggle re-enables a disabled app (AC3)',
        (tester) async {
      final store =
          AppVisibilityStore.inMemory(initialDisabled: {'ota_monitor'});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: [_m('ota_monitor')],
            store: store,
            onClose: () {},
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('manage_toggle_ota_monitor')));
      await tester.pump();

      expect(store.isEnabled('ota_monitor'), isTrue);
      final sw = tester.widget<Switch>(
          find.byKey(const Key('manage_toggle_ota_monitor')));
      expect(sw.value, isTrue);
    });

    testWidgets('onClose callback is called when back button tapped',
        (tester) async {
      var closed = false;
      final store = AppVisibilityStore.inMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: [_m('ota_monitor')],
            store: store,
            onClose: () => closed = true,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('manage_apps_back_button')));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('empty app list renders empty state (no crash)', (tester) async {
      final store = AppVisibilityStore.inMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ManageAppsPanel(
            allApps: const [],
            store: store,
            onClose: () {},
          ),
        ),
      ));

      expect(find.byKey(const Key('manage_apps_panel')), findsOneWidget);
      expect(find.text('No apps discovered'), findsOneWidget);
    });
  });

  // ── AC3 + AC2 integration via HmiLauncherApp ──────────────────────────

  group('Manage Apps via launcher shell (AC3 integration)', () {
    testWidgets('manage_apps_button tap opens the manage_apps_panel (AC3)',
        (tester) async {
      await _wideView(tester);

      final store = AppVisibilityStore.inMemory();
      final registry = _registry([
        _m('ota_monitor', name: 'OTA Monitor'),
        _m('adsw_monitor', name: 'AD SW'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: store,
        panelBuilder: (app) =>
            Center(key: Key('stub_${app.id}'), child: Text(app.name)),
        aiService: _testAiService,
      ));

      // Open Manage Apps from the top-bar grid icon button.
      await tester.tap(find.byKey(const Key('manage_apps_button')));
      await tester.pump();

      expect(find.byKey(const Key('manage_apps_panel')), findsOneWidget);
      expect(find.byKey(const Key('manage_toggle_ota_monitor')), findsOneWidget);
      expect(
          find.byKey(const Key('manage_toggle_adsw_monitor')), findsOneWidget);
    });

    testWidgets(
        'disabling an app in Manage Apps removes it from sidebar (AC2+AC3)',
        (tester) async {
      await _wideView(tester);

      final store = AppVisibilityStore.inMemory();
      final registry = _registry([
        _m('ota_monitor', name: 'OTA Monitor'),
        _m('adsw_monitor', name: 'AD SW'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: store,
        panelBuilder: (app) =>
            Center(key: Key('stub_${app.id}'), child: Text(app.name)),
        aiService: _testAiService,
      ));

      // Both sidebar items present before opening manage panel.
      expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
      expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);

      // Open Manage Apps panel.
      await tester.tap(find.byKey(const Key('manage_apps_button')));
      await tester.pump();

      // Disable adsw_monitor.
      await tester.tap(find.byKey(const Key('manage_toggle_adsw_monitor')));
      await tester.pump();

      // Close the panel by tapping the back button.
      await tester.tap(find.byKey(const Key('manage_apps_back_button')));
      await tester.pump();

      // adsw_monitor must no longer appear in the sidebar.
      expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsNothing);
      expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
    });

    testWidgets(
        're-enabling an app in Manage Apps adds it back to sidebar (AC3)',
        (tester) async {
      await _wideView(tester);

      // Start with adsw_monitor disabled.
      final store =
          AppVisibilityStore.inMemory(initialDisabled: {'adsw_monitor'});
      final registry = _registry([
        _m('ota_monitor', name: 'OTA Monitor'),
        _m('adsw_monitor', name: 'AD SW'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: store,
        panelBuilder: (app) =>
            Center(key: Key('stub_${app.id}'), child: Text(app.name)),
        aiService: _testAiService,
      ));

      // adsw_monitor must not be in the sidebar initially.
      expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsNothing);
      expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);

      // Re-enable adsw_monitor via Manage Apps.
      await tester.tap(find.byKey(const Key('manage_apps_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('manage_toggle_adsw_monitor')));
      await tester.pump();
      // Close the panel.
      await tester.tap(find.byKey(const Key('manage_apps_back_button')));
      await tester.pump();

      // Must now appear in the sidebar.
      expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);
    });

    testWidgets('home grid count updates when an app is disabled (AC3)',
        (tester) async {
      await _wideView(tester);

      final store = AppVisibilityStore.inMemory();
      final registry = _registry([
        _m('ota_monitor', name: 'OTA Monitor'),
        _m('adsw_monitor', name: 'AD SW'),
      ]);

      await tester.pumpWidget(HmiLauncherApp(
        initialRegistry: registry,
        enableRos: false,
        visibilityStore: store,
        panelBuilder: (app) =>
            Center(key: Key('stub_${app.id}'), child: Text(app.name)),
        aiService: _testAiService,
      ));

      expect(find.textContaining('2 apps installed'), findsWidgets);

      // Disable one app via Manage Apps.
      await tester.tap(find.byKey(const Key('manage_apps_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('manage_toggle_adsw_monitor')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('manage_apps_back_button')));
      await tester.pump();

      expect(find.textContaining('1 app installed'), findsWidgets);
    });
  });
}
