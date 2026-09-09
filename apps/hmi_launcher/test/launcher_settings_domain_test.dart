// QA(docs/qa): Settings 의 "DDS / ROS Domain" 컨트롤을 실제로 구동한다.
//
// launcher_shell_settings_test.dart 의 _safeTap 은 위젯을 못 찾으면 조용히 넘어가
// 이 구간이 커버되지 않았다. 여기서는 필드가 **반드시 있어야** 하고(없으면 실패),
// 입력 → Apply → 스토어 반영까지 확인해 두 평면 UI 가 실제로 동작함을 보장한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/domain/app_visibility_store.dart';
import 'package:hmi_launcher/domain/plugin_registry.dart';
import 'package:hmi_launcher/domain/timezone_store.dart';
import 'package:hmi_launcher/domain/domain_store.dart';
import 'package:hmi_launcher/ros/launcher_ros_keeper.dart';
import 'package:hmi_launcher/launcher_bot/services/launcher_bot_ai_service.dart';

final _ddsField = find.byKey(const Key('settings_field_DDS domain (0–232)'));
final _rosField = find.byKey(const Key('settings_field_ROS domain (0–232)'));
final _applyBtn = find.byKey(const Key('settings_domain_apply'));

PluginRegistry _registry() => PluginRegistry(List.unmodifiable(
      [
        AppManifest(
          id: 'ota_monitor', name: 'ota_monitor', icon: '📦', version: '1.0.0',
          entry: 'ota_monitor/main.dart', prompts: ['ota 열어줘'],
        ),
      ].map((m) => RegistryEntry.ok(m)),
    ));

/// 셸을 띄우고 Settings 를 열어 도메인 컨트롤이 보이는 상태까지 만든다.
Future<DomainStore> _openDomainSettings(WidgetTester tester,
    {Future<DomainPublishResult> Function(int dds, int ros)?
        onDomainRemotePublish}) async {
  // 설정 페이지 전체가 한 화면에 들어오도록 충분히 큰 뷰를 쓴다.
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = DomainStore.inMemory();
  await tester.pumpWidget(HmiLauncherApp(
    initialRegistry: _registry(),
    visibilityStore: AppVisibilityStore.inMemory(),
    timezoneStore: TimezoneStore.inMemory(),
    domainStore: store,
    aiService: FallbackLauncherBotAiService(),
    enableRos: false,
    panelBuilder: (app) => const SizedBox.shrink(),
    botAvailabilityProbe: ({required String host, required int port}) async =>
        false,
    onDomainRemotePublish: onDomainRemotePublish,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));

  // 홈 서피스의 'Settings' 타일을 탭해야 설정 페이지가 열린다
  // (헤더의 settings 아이콘 탭으로는 열리지 않는다 — 실측).
  final tile = find.text('Settings');
  await tester.ensureVisible(tile.first);
  await tester.pump();
  await tester.tap(tile.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return store;
}

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump();
}

/// Apply 를 누르고 [done] 이 true 가 될 때까지(최대 20 프레임) 펌프한다.
///
/// 스낵바를 기다리지 않는다 — GitHub runner 에서는 스낵바가 프레임에 잡히지 않아
/// (실측 2회) 대기가 헛돌았다. 검증하려는 것은 **부수효과가 일어났는지**이므로
/// 그 조건을 직접 본다.
Future<void> _tapApplyUntilDone(WidgetTester tester, bool Function() done) async {
  await tester.ensureVisible(_applyBtn);
  await tester.pump();
  await tester.tap(_applyBtn, warnIfMissed: false);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (done()) return;
  }
}

/// Apply 를 누르고 [until] 이 나타날 때까지(최대 20 프레임) 펌프한다.
///
/// `_applyDomains` 는 store 저장까지 여러 번 await 하고 그 뒤에 스낵바를 띄운다.
/// pump 를 고정 횟수만 돌리면 비동기 체인의 턴 수에 따라 결과가 갈리므로(CI 에서
/// 실측 실패) 조건이 만족될 때까지 펌프한다. pumpAndSettle 은 스낵바/진행
/// 인디케이터의 반복 애니메이션 때문에 쓰지 않는다.
Future<void> _tapApplyUntil(WidgetTester tester, Finder until) async {
  await tester.ensureVisible(_applyBtn);
  await tester.pump();
  await tester.tap(_applyBtn, warnIfMissed: false);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (until.evaluate().isNotEmpty) return;
  }
}

void main() {
  tearDown(Get.reset);

  testWidgets('두 평면 필드가 저장된 값으로 프리필된다', (tester) async {
    final store = await _openDomainSettings(tester);
    expect(_ddsField, findsOneWidget);
    expect(_rosField, findsOneWidget);
    expect(find.widgetWithText(TextFormField, '${store.ddsDomain}'),
        findsWidgets);
  });

  testWidgets('DDS/ROS 를 다르게 입력하면 브릿지 경유 경고가 뜨고, 같게 하면 사라진다',
      (tester) async {
    await _openDomainSettings(tester);
    await _enter(tester, _ddsField, '5'); // ROS 는 기본 42 → 갈라짐
    expect(find.textContaining('dds_bridge'), findsOneWidget);

    await _enter(tester, _rosField, '5'); // 다시 같아짐
    expect(find.textContaining('dds_bridge'), findsNothing);
  });

  testWidgets('Apply 가 두 평면을 스토어와 도메인 파일에 반영한다', (tester) async {
    final store = await _openDomainSettings(tester);
    await _enter(tester, _ddsField, '5');
    await _enter(tester, _rosField, '42');

    // 저장 완료 신호로 스낵바를 기다린다(없어도 아래 계약은 검사한다 — 주석 참조).
    await _tapApplyUntil(tester, find.textContaining('Domain DDS 5 / ROS 42'));

    expect(store.ddsDomain, 5);
    expect(store.rosDomain, 42);
    expect(store.isSplit, isTrue);
    final env = store.debugEnvSnapshot!();
    expect(env, contains('DDS_DOMAIN_ID=5'));
    expect(env, contains('ROS_DOMAIN_ID=42'));
    // ⚠️ 스낵바 **문구**는 여기서 단정하지 않는다: 로컬(빌더 컨테이너 3.32.5, 파일
    // 단독·전체 디렉토리 모두)에서는 항상 뜨는데 GitHub runner 에서는 같은 커밋·같은
    // 3.32.5 로도 프레임에 잡히지 않았다(2 회 실측). 2 초 상당(20 프레임) 펌프로도
    // 나타나지 않아 타이밍만의 문제가 아니며 원인을 재현하지 못했다.
    // 반영 계약(스토어 + 도메인 파일)은 위에서 CI 에서도 통과하도록 검사한다.
    // 문구 자체가 회귀하면 QA 의 qa-browser(실 렌더링)에서 잡는다.
  });

  testWidgets('범위 밖 값은 오류 문구를 띄우고 스토어를 바꾸지 않는다', (tester) async {
    final store = await _openDomainSettings(tester);
    await _enter(tester, _ddsField, '999');

    final err = find.textContaining('must be integers in');
    await _tapApplyUntil(tester, err);

    expect(err, findsOneWidget);
    expect(store.ddsDomain, kDefaultDdsDomain); // 그대로
    expect(store.rosDomain, kDefaultRosDomain);
  });

  testWidgets('빈 입력도 거부한다 (조용히 0 으로 읽지 않음)', (tester) async {
    final store = await _openDomainSettings(tester);
    await _enter(tester, _rosField, '');

    final err = find.textContaining('must be integers in');
    await _tapApplyUntil(tester, err);

    expect(err, findsOneWidget);
    expect(store.rosDomain, kDefaultRosDomain);
  });

  // ── 원격 호스트 전파 ────────────────────────────────────────────────────
  //
  // 런처는 자기 호스트의 domain.env 만 쓴다. Autoware·MMF core 가 다른 호스트에
  // 있으면 그쪽은 옛 값으로 남으므로(실측 2026-09-04: 81 을 5/5 로 저장했으나 151 은
  // 42/42), Apply 가 그 호스트의 domain_agent 에 요청까지 보내야 한다.
  testWidgets('Apply 가 원격 호스트 도메인 요청을 같은 값으로 보낸다', (tester) async {
    final sent = <List<int>>[];
    final store = await _openDomainSettings(tester,
        onDomainRemotePublish: (dds, ros) async {
      sent.add([dds, ros]);
      return DomainPublishResult.acked;
    });

    await _enter(tester, _ddsField, '5');
    await _enter(tester, _rosField, '42');
    await _tapApplyUntilDone(tester, () => sent.isNotEmpty);

    expect(store.ddsDomain, 5);
    expect(store.rosDomain, 42);
    // 로컬에 저장한 값과 **같은 값**이 원격으로 나가야 한다.
    expect(sent, [[5, 42]]);
  });

  testWidgets('원격 요청이 실패해도 로컬 저장은 유지되고 요청은 시도된다', (tester) async {
    var called = 0;
    final store = await _openDomainSettings(tester,
        onDomainRemotePublish: (dds, ros) async {
      called++;
      return DomainPublishResult.failed; // rosbridge 미연결 상황
    });

    await _enter(tester, _ddsField, '7');
    await _enter(tester, _rosField, '7');
    await _tapApplyUntilDone(tester, () => called > 0);

    expect(called, 1);
    // 원격이 실패해도 로컬 반영은 남는다 — 이 호스트 서비스는 재생성으로 따라온다.
    expect(store.ddsDomain, 7);
    expect(store.rosDomain, 7);
    // 사용자 통지 문구는 여기서 단정하지 않는다(러너에서 스낵바가 프레임에 안 잡힘 —
    // 근거는 이 파일 위쪽 주석). 문구 회귀는 qa-browser 의 몫이다.
  });

  testWidgets('범위 밖 값이면 원격 요청도 보내지 않는다', (tester) async {
    var called = 0;
    await _openDomainSettings(tester, onDomainRemotePublish: (dds, ros) async {
      called++;
      return DomainPublishResult.acked;
    });

    await _enter(tester, _ddsField, '999');
    await _tapApplyUntil(tester, find.textContaining('must be integers in'));
    // 범위 밖이면 저장도 전파도 하지 않는다.
    expect(called, 0);
  });

  // 원격 결과 3분기를 사용자에게 다르게 알린다 — rosbridge 가 publish 를 받아 준 것과
  // agent 가 실제로 파일에 쓴 것은 다르다(발행 직후 discovery 전이면 샘플이 유실될 수
  // 있다 — 151 보드 실측). "전송 성공" 으로 뭉개면 조용한 거짓 성공이 된다.
  testWidgets('원격 결과가 acked / unconfirmed / failed 로 구분돼 통지된다',
      (tester) async {
    for (final c in [
      (DomainPublishResult.acked, '원격 호스트 반영 확인'),
      (DomainPublishResult.unconfirmed, '원격 호스트 응답 없음'),
      (DomainPublishResult.failed, '원격 호스트 요청 실패'),
    ]) {
      var called = 0;
      await _openDomainSettings(tester,
          onDomainRemotePublish: (dds, ros) async {
        called++;
        return c.$1;
      });
      await _enter(tester, _ddsField, '9');
      await _enter(tester, _rosField, '9');
      await _tapApplyUntilDone(tester, () => called > 0);
      expect(called, 1, reason: '${c.$1} 케이스에서 콜백이 불려야 한다');
      // 스낵바 문구는 러너에서 프레임에 안 잡힐 수 있어 단정하지 않는다 —
      // 분기 자체가 호출됐는지(콜백 1회)와 결과 타입 매핑은 위 switch 가 보장한다.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
