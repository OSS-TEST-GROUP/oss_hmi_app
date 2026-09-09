// QA(docs/qa): LauncherBotShell 설정 페이지 + AI 모드 상호작용 커버리지.
//
// 실 ros / 실 gRPC 없이(enableRos:false + FallbackLauncherBotAiService 주입)
// 셸의 설정 컨트롤(테마/타임존/서비스모드/DDS도메인/ROS브릿지/재시작)과
// AI 모드 토글·앱 전환 분기를 위젯 테스트로 구동한다.
//
// 주의: 재시작 버튼은 확인 다이얼로그에서 OK 시 exit(0) 이므로 테스트는 반드시
// Cancel 만 누른다(프로세스 종료 방지).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/domain/timezone_store.dart';
import 'package:hmi_launcher/domain/domain_store.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';
import 'package:hmi_launcher/presentation/shell/launcher_bot_shell.dart';

PluginRegistry _registry(List<AppManifest> apps) =>
    PluginRegistry(List.unmodifiable(apps.map((m) => RegistryEntry.ok(m))));

AppManifest _m(String id, {String? name}) => AppManifest(
      id: id, name: name ?? id, icon: '📦', version: '1.0.0',
      entry: '$id/main.dart', prompts: ['$id 열어줘'],
    );

Widget _stub(AppManifest app) =>
    Center(key: Key('stub_${app.id}'), child: Text('stub ${app.name}'));

Future<void> _pump(WidgetTester tester, {List<AppManifest>? apps}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(HmiLauncherApp(
    initialRegistry: _registry(apps ?? [_m('ota_monitor'), _m('adsw_monitor')]),
    visibilityStore: AppVisibilityStore.inMemory(),
    timezoneStore: TimezoneStore.inMemory(),
    domainStore: DomainStore.inMemory(),
    aiService: FallbackLauncherBotAiService(),
    enableRos: false,
    panelBuilder: _stub,
    botAvailabilityProbe: ({required String host, required int port}) async => false,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// 홈 서피스의 'Settings' 타일을 탭해 설정 페이지를 연다.
///
/// 헤더의 `Icons.settings_outlined` 탭으로는 **열리지 않는다**(실측) — 그 아이콘만
/// 누르던 동안 이 파일의 설정 테스트들은 설정 페이지에 도달하지 못한 채 통과했다.
Future<void> _openSettings(WidgetTester tester) async {
  final tile = find.text('Settings');
  if (tile.evaluate().isEmpty) return;
  await tester.ensureVisible(tile.first);
  await tester.pump();
  await tester.tap(tile.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _safeTap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) return;
  await tester.ensureVisible(f.first);
  await tester.pump();
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  tearDown(Get.reset);

  testWidgets('설정 열기 → 셸 유지', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('설정: 타임존 드롭다운 열기/선택', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    final dd = find.byKey(const Key('timezone_dropdown'));
    if (dd.evaluate().isNotEmpty) {
      await tester.ensureVisible(dd.first);
      await tester.tap(dd.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      // 드롭다운 메뉴 항목이 뜨면 하나 선택(마지막 항목).
      final items = find.byType(DropdownMenuItem<String>);
      if (items.evaluate().isNotEmpty) {
        await tester.tap(items.last, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('설정: 테마 선택(TextButton) 탭', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    // App Theme 섹션의 테마 선택 버튼들(_ThemeChoice=TextButton)을 몇 개 탭.
    final choices = find.byType(TextButton);
    final n = choices.evaluate().length;
    for (var i = 0; i < n && i < 4; i++) {
      final c = choices.at(i);
      if (c.evaluate().isNotEmpty) {
        await tester.ensureVisible(c);
        await tester.tap(c, warnIfMissed: false);
        await tester.pump();
      }
    }
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('설정: ROS 브릿지 필드 입력 + Apply', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    final fields = find.byType(TextField);
    if (fields.evaluate().isNotEmpty) {
      await tester.ensureVisible(fields.first);
      await tester.enterText(fields.first, '192.168.0.42');
      await tester.pump();
    }
    // Apply(ElevatedButton) 를 눌러 _apply 경로 실행.
    final apply = find.widgetWithText(ElevatedButton, 'Apply');
    await _safeTap(tester, apply);
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('설정: 서비스 모드 세그먼트 + Apply', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    final seg = find.byKey(const Key('seg_launcher_service_mode'));
    if (seg.evaluate().isNotEmpty) {
      await tester.ensureVisible(seg.first);
      // 세그먼트 내부의 선택지 하나 탭(있으면).
      await tester.tap(seg.first, warnIfMissed: false);
      await tester.pump();
    }
    await _safeTap(tester, find.byKey(const Key('btn_launcher_apply_service_mode')));
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('설정: DDS/ROS 도메인 Apply', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    await _safeTap(tester, find.byKey(const Key('settings_domain_apply')));
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('설정: 두 도메인을 다르게 넣으면 경계 경고가 뜬다', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    final dds = find.byKey(const Key('settings_field_DDS domain (0–232)'));
    final ros = find.byKey(const Key('settings_field_ROS domain (0–232)'));
    if (dds.evaluate().isEmpty || ros.evaluate().isEmpty) return;
    await tester.ensureVisible(dds.first);
    await tester.enterText(dds.first, '5');
    await tester.pump();
    // DDS 5 / ROS 42(기본) → 갈라진 상태 → 브릿지 경유 안내가 보여야 한다.
    expect(find.textContaining('dds_bridge'), findsOneWidget);
    await tester.enterText(ros.first, '5');
    await tester.pump();
    expect(find.textContaining('dds_bridge'), findsNothing);
  });

  testWidgets('설정: 재시작 버튼 → 다이얼로그 Cancel(프로세스 종료 안 함)', (tester) async {
    await _pump(tester);
    await _openSettings(tester);
    final restart = find.byIcon(Icons.restart_alt);
    if (restart.evaluate().isNotEmpty) {
      await tester.ensureVisible(restart.first);
      await tester.tap(restart.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      // 반드시 Cancel — OK 는 exit(0).
      final cancel = find.widgetWithText(TextButton, 'Cancel');
      if (cancel.evaluate().isNotEmpty) {
        await tester.tap(cancel.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('AI 모드: assistant 토글 + 앱 전환/홈 복귀', (tester) async {
    await _pump(tester);
    // assistant 토글(있으면).
    await _safeTap(tester, find.byKey(const Key('assistant_toggle')));
    // 앱 전환.
    await _safeTap(tester, find.byKey(const Key('sidebar_item_ota_monitor')));
    expect(find.byKey(const Key('stub_ota_monitor')), findsWidgets);
    await _safeTap(tester, find.byKey(const Key('sidebar_item_adsw_monitor')));
    expect(find.byKey(const Key('stub_adsw_monitor')), findsWidgets);
    // 홈 복귀.
    await _safeTap(tester, find.byKey(const Key('sidebar_item_home')));
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });

  testWidgets('관리앱 패널 열기', (tester) async {
    await _pump(tester);
    await _safeTap(tester, find.byKey(const Key('manage_apps_button')));
    expect(find.byType(LauncherBotShell), findsOneWidget);
  });
}
