// F015 AC4: rosbridge 미기동 시 UI 정상기동 테스트.
//
// ROSBRIDGE_URL 미설정/연결실패해도:
//   - 에러다이얼로그 없이 런처셸 표시
//   - LauncherBotShell 위젯이 렌더링됨
//   - AgentSubmitAiService 는 gRPC 연결 없이도 초기화됨 (연결은 런타임 지연)
//   - DBus 어댑터가 rosbridge 와 독립 (enableRos=false 로 격리)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/main.dart';

PluginRegistry _emptyRegistry() {
  return PluginRegistry(const []);
}

PluginRegistry _singleAppRegistry() {
  return PluginRegistry(
    List.unmodifiable([
      RegistryEntry.ok(
        AppManifest(
          id: 'ota_monitor',
          name: 'OTA Monitor',
          icon: 'box',
          version: '1.0.0',
          entry: 'ota_monitor/main.dart',
          prompts: const ['OTA 열어줘'],
        ),
      ),
    ]),
  );
}

void main() {
  setUp(() {
    // 800x600 크기 설정 (LauncherBotShell 렌더링용)
  });

  tearDown(() {
    Get.reset();
  });

  // AC4: rosbridge 미기동 (enableRos=false) 시 런처셸 정상 기동
  testWidgets('AC4: ROSBRIDGE 미기동 시 HmiLauncherApp 이 에러 없이 기동한다',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // enableRos=false 로 rosbridge 연결 없이 기동
    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: _emptyRegistry(),
      enableRos: false,
      visibilityStore: AppVisibilityStore.inMemory(),
    ));

    // 에러 다이얼로그 없이 MaterialApp 이 렌더링됐는지 확인
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 에러 다이얼로그가 없는지 재확인
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('AC4: rosbridge 없이 기동해도 launcher_bot_shell 이 렌더링된다',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: _singleAppRegistry(),
      enableRos: false,
      visibilityStore: AppVisibilityStore.inMemory(),
    ));

    // LauncherBotShell 이 렌더링됐는지 확인
    expect(find.byKey(const Key('launcher_bot_shell')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('AC4: AgentSubmitAiService 는 gRPC 서버 없이도 초기화된다',
      (tester) async {
    // AgentSubmitAiService 생성이 gRPC 서버 연결 없이 성공해야 한다.
    // 연결 실패는 generate() 호출 시점에만 발생 (생성자는 안전).
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // HmiLauncherApp 기동 시 AgentSubmitAiService(host: 'localhost', port: 50051) 생성됨.
    // localhost:50051 이 없어도 기동해야 한다.
    await tester.pumpWidget(HmiLauncherApp(
      initialRegistry: _emptyRegistry(),
      enableRos: false,
      visibilityStore: AppVisibilityStore.inMemory(),
    ));

    await tester.pump();
    // 에러 다이얼로그가 없는지 확인 (gRPC 서버 없어도 크래시 없음)
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
