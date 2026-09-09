// QA(docs/qa): Rviz2MonitorApp 스모크 — TR-3 seam 으로 실 docker 없이 렌더 검증.
//
// fake ProcessRunner 를 주입한 컨트롤러를 미리 Get.put → Rviz2ViewPage.initState
// 가 이를 재사용해 실 Process.run/폴링 타이머 문제 없이 위젯 트리를 빌드한다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:rviz2_panel/main.dart';

void main() {
  testWidgets('Rviz2MonitorApp 은 상태 카드/제어 UI 를 렌더한다', (tester) async {
    // 오버플로우 노이즈 억제(작은 테스트 뷰포트).
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);

    Get.reset();
    final cfg = AppConfig.defaults();
    final ctrl = Rviz2Controller(
      cfg: cfg,
      run: (exe, args) async => ProcessResult(0, 0, 'running|||0', ''),
    );
    Get.put<Rviz2Controller>(ctrl);

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(Rviz2MonitorApp(cfg: cfg));
    await tester.pump();

    // 제어 헤딩 + Start/Stop 버튼이 보인다(구 'rviz2 Container' → 'RViz2 Control').
    expect(find.text('RViz2 Control'), findsOneWidget);
    expect(find.text('Start'), findsWidgets);
    expect(find.text('Stop'), findsWidgets);

    // 정리: 폴링 Timer 취소 + dispose.
    ctrl.onClose();
    await tester.pumpWidget(const SizedBox());
    Get.delete<Rviz2Controller>(force: true);
    Get.reset();
  });
}
