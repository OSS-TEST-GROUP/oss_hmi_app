// QA(docs/qa): Rviz2ViewPage 위젯 — 상태 카드/에러 배너/제어 버튼 렌더 + 인터랙션.
//
// TR-3 seam(ProcessRunner 주입)으로 실 docker/gRPC 없이 위젯 테스트가 가능해졌다.
// fake runner 를 주입한 컨트롤러를 미리 Get.put → initState 가 이를 재사용하므로
// 실 Process.run 이 발생하지 않는다. onInit 의 폴링 Timer 는 본문 끝 onClose 로 취소.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:rviz2_panel/config/app_config.dart';
import 'package:rviz2_panel/config/user_config_store.dart';
import 'package:rviz2_panel/controller/rviz2_controller.dart';
import 'package:rviz2_panel/data/rviz2_data.dart';
import 'package:rviz2_panel/view/rviz2_view_page.dart';

ProcessRunner _fake({String inspectOut = 'running|||0'}) {
  return (String exe, List<String> args) async {
    if (args.contains('inspect')) return ProcessResult(0, 0, inspectOut, '');
    if (args.contains('logs')) return ProcessResult(0, 0, '[INFO] ok', '');
    if (args.isNotEmpty && args.first == 'run') {
      return ProcessResult(0, 0, 'cid', '');
    }
    return ProcessResult(0, 0, '', '');
  };
}

void _suppressOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<Rviz2Controller> _pump(WidgetTester tester,
    {String inspectOut = 'running|||0'}) async {
  _suppressOverflow();
  Get.reset();
  final cfg = AppConfig.defaults();
  final ctrl = Rviz2Controller(cfg: cfg, run: _fake(inspectOut: inspectOut));
  Get.put<Rviz2Controller>(ctrl); // onInit → 폴링 Timer + fake refreshStatus
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Rviz2ViewPage(cfg: cfg)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ctrl;
}

Future<void> _cleanup(WidgetTester tester, Rviz2Controller ctrl) async {
  ctrl.onClose(); // 폴링 Timer 취소
  await tester.pumpWidget(const SizedBox());
  Get.delete<Rviz2Controller>(force: true);
  Get.reset();
}

void main() {
  testWidgets('제어 헤딩 + Start/Stop 버튼 렌더', (tester) async {
    final ctrl = await _pump(tester);
    expect(find.text('RViz2 Control'), findsOneWidget);
    expect(find.text('Start'), findsWidgets);
    expect(find.text('Stop'), findsWidgets);
    await _cleanup(tester, ctrl);
  });

  testWidgets('running 상태 배지 렌더', (tester) async {
    final ctrl = await _pump(tester); // fake inspect = running
    expect(find.textContaining('RUNNING'), findsWidgets);
    await _cleanup(tester, ctrl);
  });

  testWidgets('notInstalled 상태 배지 렌더', (tester) async {
    final ctrl = await _pump(tester, inspectOut: '???|||0');
    expect(find.textContaining('INSTALLED'), findsWidgets);
    await _cleanup(tester, ctrl);
  });

  testWidgets('lastError 설정 시 에러 배너 + 닫기', (tester) async {
    final ctrl = await _pump(tester);
    ctrl.lastError.value = '테스트 오류';
    await tester.pump();
    expect(find.textContaining('테스트 오류'), findsWidgets);
    final close = find.byIcon(Icons.close);
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await tester.pump();
    }
    await _cleanup(tester, ctrl);
  });

  testWidgets('Refresh / Start / Stop 버튼 탭(fake runner)', (tester) async {
    final ctrl = await _pump(tester);
    for (final f in [
      find.byIcon(Icons.refresh),
      find.text('Start'),
      find.text('Stop'),
    ]) {
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    expect(find.text('RViz2 Control'), findsOneWidget);
    await _cleanup(tester, ctrl);
  });

  testWidgets('로그 라인 렌더(_LogLineRow — 레벨별)', (tester) async {
    final ctrl = await _pump(tester);
    final now = DateTime(2026);
    ctrl.logs.addAll([
      LogLine(level: 40, name: 'rviz2', msg: 'plugin load failed', ts: now),
      LogLine(level: 30, name: 'rviz2', msg: 'deprecated flag', ts: now),
      LogLine(level: 20, name: 'rviz2', msg: 'booting ok', ts: now),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('plugin load failed'), findsWidgets);
    await _cleanup(tester, ctrl);
  });

  // 주: 'View rviz2' 탭(showRviz2)은 _activateAglSurface 의 **네이티브 gRPC**
  // (ProcessRunner seam 밖 — 127.0.0.1:14005 채널)를 호출해 FakeAsync 에서
  // pending-timer 를 남기므로 위젯 테스트에서 제외한다(잔여 통합경계, TR-3 note).

  testWidgets('기본값 채우기(Autoware preset) 탭', (tester) async {
    final ctrl = await _pump(tester);
    final preset = find.text('기본값 채우기');
    if (preset.evaluate().isNotEmpty) {
      await tester.ensureVisible(preset.first);
      await tester.tap(preset.first, warnIfMissed: false);
      await tester.pump();
    }
    expect(find.text('RViz2 Control'), findsOneWidget);
    await _cleanup(tester, ctrl);
  });

  testWidgets('패널 설정 저장/리셋 버튼 탭', (tester) async {
    final ctrl = await _pump(tester);
    for (final key in ['panel_settings_reset', 'panel_settings_save']) {
      final btn = find.byKey(Key(key));
      if (btn.evaluate().isNotEmpty) {
        await tester.ensureVisible(btn.first);
        await tester.tap(btn.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    expect(find.text('RViz2 Control'), findsOneWidget);
    await _cleanup(tester, ctrl);
  });

  testWidgets('옵션/설정 TextField 입력 → onChanged 경로', (tester) async {
    final ctrl = await _pump(tester);
    final fields = find.byType(TextField);
    final n = fields.evaluate().length;
    for (var i = 0; i < n && i < 3; i++) {
      final f = fields.at(i);
      await tester.ensureVisible(f);
      await tester.enterText(f, 'edited_$i');
      await tester.pump();
    }
    expect(find.text('RViz2 Control'), findsOneWidget);
    await _cleanup(tester, ctrl);
  });

  testWidgets('embedded 모드 렌더', (tester) async {
    _suppressOverflow();
    Get.reset();
    final cfg = AppConfig.defaults();
    final ctrl = Rviz2Controller(cfg: cfg, run: _fake());
    Get.put<Rviz2Controller>(ctrl);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Rviz2ViewPage(cfg: cfg, embedded: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Rviz2ViewPage), findsOneWidget);
    await _cleanup(tester, ctrl);
  });

  // ─── Run Options 영속화 (ROS_DOMAIN_ID) ────────────────────────────────────
  //
  // 예전에는 Run Options 세 값이 `docker run` 인자로만 쓰이고 저장되지 않아, 앱을
  // 다시 띄우면 프리필이 이전 값으로 되돌아갔다(사용자 지적). Start 시점에
  // config.json 에 기록해 재시작 후에도 유지되는지 고정한다.
  // Start 가 **저장을 호출하는지**는 기록형 스토어로 본다 — 실제 파일 I/O 는
  // 위젯 테스트의 fake-async 로 완료를 기다릴 수 없어서다(이 프로젝트의 기존 함정).
  // 파일까지의 왕복은 아래 순수 테스트('저장소 왕복')가 담당한다 — UI→스토어와
  // 스토어→파일을 두 계층으로 나눠 검증하는 기존 방식.
  testWidgets('Start 를 누르면 편집한 ROS_DOMAIN_ID 가 저장 요청된다',
      (tester) async {
    _suppressOverflow();
    Get.reset();
    final store = _RecordingStore();
    final cfg = AppConfig.defaults();
    // start() 는 실제 gRPC(homebar)를 부르고 그 뒤에 1.2초 지연을 걸어, fake-async
    // 에서는 절대 완료되지 않는다 → "A Timer is still pending" 으로 깨진다(실측).
    // 여기서 보려는 것은 "Start 가 저장을 호출하는가" 이므로 start 만 대역으로 막는다.
    final ctrl =
        _NoStartController(cfg: cfg, run: _fake(inspectOut: 'exited|||0'));
    Get.put<Rviz2Controller>(ctrl);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Rviz2ViewPage(cfg: cfg, userConfigStore: store),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
        find.widgetWithText(TextField, 'ROS_DOMAIN_ID'), '10');
    await tester.pump();
    // 이 화면은 테스트 뷰포트에서 오버플로우한다(_suppressOverflow 참조) — 버튼이
    // 화면 밖일 수 있으므로 스크롤해 올리고 warnIfMissed 를 끈다(기존 테스트와 동일).
    final startBtn = find.text('Start').first;
    await tester.ensureVisible(startBtn);
    await tester.pump();
    await tester.tap(startBtn, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));

    expect(store.saved, isNotNull, reason: 'Start 가 저장을 호출해야 한다');
    expect(store.saved!.defaultDomainId, '10');
    // 저장 시점부터 런처 Settings 가 이 값을 덮어쓰지 않아야 한다.
    expect(store.saved!.domainIdFromUser, isTrue);

    await _cleanup(tester, ctrl);
  });

  testWidgets('저장된 도메인은 재시작 프리필에 쓰인다', (tester) async {
    _suppressOverflow();
    Get.reset();
    // 앱 재시작 = 저장된 cfg 로 페이지를 새로 만드는 것과 같다.
    final restored = AppConfig.defaults().copyWith(
      defaultDomainId: '10',
      domainIdFromUser: true,
    );
    final ctrl =
        Rviz2Controller(cfg: restored, run: _fake(inspectOut: 'exited|||0'));
    Get.put<Rviz2Controller>(ctrl);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Rviz2ViewPage(cfg: restored)));
    await tester.pump(const Duration(milliseconds: 50));

    final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'ROS_DOMAIN_ID'));
    expect(field.controller!.text, '10');

    await _cleanup(tester, ctrl);
  });

  // 위 위젯 테스트가 러너 환경에 따라 흔들려도 계약 자체는 여기서 고정된다.
  test('저장소 왕복: 도메인이 유지되고 런처 값이 덮어쓰지 못한다', () async {
    final dir = await Directory.systemTemp.createTemp('rviz2_panel_store');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = UserConfigStore(
      path: '${dir.path}/config.json',
      defaultPath: '${dir.path}/config_def.json',
    );
    final cfg = AppConfig.defaults()
        .copyWith(defaultDomainId: '10', domainIdFromUser: true);

    expect(await store.save(cfg), isNull);
    final back = await store.load();
    expect(back!.defaultDomainId, '10');
    expect(back.domainIdFromUser, isTrue);
    expect(back.withDomainId('42').defaultDomainId, '10');
  });
}

/// 저장 호출만 기록하는 스토어 — 파일 I/O 없이 "Start 가 저장했는가" 를 본다.
class _RecordingStore extends UserConfigStore {
  _RecordingStore() : super(path: '/dev/null/x', defaultPath: '/dev/null/y');
  AppConfig? saved;
  @override
  Future<String?> save(AppConfig cfg) async {
    saved = cfg;
    return null;
  }
}

/// start() 만 무력화한 컨트롤러 — 저장 호출 여부만 보려는 테스트용.
/// (실제 start 는 gRPC + 1.2초 지연이라 fake-async 에서 끝나지 않는다)
class _NoStartController extends Rviz2Controller {
  _NoStartController({required super.cfg, super.run});
  @override
  Future<void> start({Map<String, String> extraEnv = const {}, Rect? rect}) async {}
}
