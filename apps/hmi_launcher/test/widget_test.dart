// E2E widget tests for the LauncherBotShell-based launcher.
//
// Coverage here is scoped to shell-level behaviour: registry → sidebar
// rendering, prompt → plugin launch, sidebar tap → embedded panel,
// and the Launcher / plugin / Launcher cycle.  Plugin-internal coverage
// lives in each plugin's own test suite.
//
// Migration note (F015): HmiLauncherApp now renders LauncherBotShell
// (AI-bot layout) instead of the old LauncherShell (Tesla-reskin layout).
// Prompts are submitted through the LauncherBotPanel input field
// (key: 'launcher_bot_input_field') after opening the assistant panel.
// Sidebar items are rendered in _AppRail with keys 'sidebar_item_<id>'
// for all installed apps.
//
// All tests inject FallbackLauncherBotAiService so the NLU fallback path
// is exercised without a real gRPC connection or long timeouts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/presentation/shell/launcher_bot_shell.dart';

/// Fallback AI service — immediately responds without a real gRPC server.
///
/// Injected through [HmiLauncherApp.aiService] in every test so the NLU
/// local-command path (substring / alias matching) is exercised without the
/// 10-second gRPC timeout that [AgentSubmitAiService] has.
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

/// Opens the LauncherBotPanel so its input field becomes available.
Future<void> _openAssistant(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('assistant_toggle')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Submits [text] through the LauncherBotPanel input field.
///
/// Requires the assistant panel to already be open (call [_openAssistant]
/// first if needed).
Future<void> _submitPrompt(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const Key('launcher_bot_input_field')),
    text,
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  // Allow NLU + FallbackLauncherBotAiService to complete and setState to propagate.
  await tester.pump(const Duration(milliseconds: 400));
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
      aiService: _testAiService,
    ));

    // F015: HmiLauncherApp now hosts LauncherBotShell.
    expect(find.byType(LauncherBotShell), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_home')), findsOneWidget);

    // Home greeting and app-count line.
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);
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
      aiService: _testAiService,
    ));

    await _openAssistant(tester);
    await _submitPrompt(tester, 'OTA 모니터 열어줘');

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
      aiService: _testAiService,
    ));

    // 'OTA Monitor' is the full app name; NluRouter's alias fallback matches
    // it even when no prompts contain the query.
    await _openAssistant(tester);
    await _submitPrompt(tester, 'OTA Monitor');

    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('non-matching input does not launch any app',
      (tester) async {
    await _wideView(tester);
    final registry = _registry([
      _m('ota_monitor', name: 'OTA Monitor', prompts: ['OTA 모니터 열어줘']),
    ]);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: registry,
      enableRos: false,
      panelBuilder: _placeholderPanel,
      aiService: _testAiService,
    ));

    await _openAssistant(tester);
    await _submitPrompt(tester, '오늘 날씨 어때');

    // The app panel must not appear — regardless of whether the bot
    // answered with an AI error or a fallback message.
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
      aiService: _testAiService,
    ));

    // Open via sidebar.
    await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);

    // Submit "close" through the bot panel — should return to home.
    await _openAssistant(tester);
    await _submitPrompt(tester, 'close');

    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsNothing);
    // Home greeting must be visible again.
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);

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
      aiService: _testAiService,
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
      aiService: _testAiService,
    ));

    expect(find.byType(LauncherBotShell), findsOneWidget);
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
      aiService: _testAiService,
    ));

    // 1. sidebar shows both plugin items
    expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);

    // 2. prompt "AD SW 모니터 열어줘" launches adsw and leaves ota alone
    await _openAssistant(tester);
    await _submitPrompt(tester, 'AD SW 모니터 열어줘');
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsNothing);

    // 3. prompt "OTA 모니터 열어줘" swaps to ota, dismissing adsw
    await _submitPrompt(tester, 'OTA 모니터 열어줘');
    expect(find.byKey(const Key('app_embedded_ota_monitor')), findsOneWidget);
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsNothing);

    await tester.pumpAndSettle();

    // 4. tapping the home item returns to the home panel
    await tester.tap(find.byKey(const Key('sidebar_item_home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);

    // 5. tapping the adsw sidebar item mounts its embedded panel again
    await tester.tap(find.byKey(const Key('sidebar_item_adsw_monitor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_embedded_adsw_monitor')), findsOneWidget);
  });
}
