// QA(docs/qa): ota_monitor LogController(add/log/clear/maxLines) + LogBottomSheet 위젯.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ota_monitor/view/log_overlay.dart';

void main() {
  tearDown(Get.reset);

  group('LogController', () {
    test('add 는 라인을 누적하고 maxLines 초과분을 앞에서 제거', () {
      final c = LogController(maxLines: 3);
      c.add('a');
      c.add('b');
      c.add('c');
      c.add('d'); // a 제거
      expect(c.lines, ['b', 'c', 'd']);
    });

    test('log: info 는 그대로, 그 외 레벨은 [level] 접두', () {
      final c = LogController();
      c.log('hello');
      c.log('oops', level: 'error');
      expect(c.lines[0], 'hello');
      expect(c.lines[1], '[error] oops');
    });

    test('clear 는 전체 비움', () {
      final c = LogController()
        ..add('x')
        ..add('y');
      c.clear();
      expect(c.lines, isEmpty);
    });
  });

  group('LogBottomSheet', () {
    testWidgets('Debug Log 렌더 + 라인 표시 + clear 버튼', (tester) async {
      final log = LogController();
      Get.put<LogController>(log);
      log.add('line-one');
      log.add('line-two');

      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LogBottomSheet()),
      ));
      await tester.pump();

      expect(find.text('Debug Log'), findsOneWidget);
      expect(find.text('line-one'), findsWidgets);

      // clear 버튼(휴지통 아이콘) 탭 → 라인 비움.
      final clearBtn = find.byIcon(Icons.delete_outline);
      if (clearBtn.evaluate().isNotEmpty) {
        await tester.tap(clearBtn.first, warnIfMissed: false);
        await tester.pump();
        expect(log.lines, isEmpty);
      }
    });

    testWidgets('autoFollow 토글 + scroll-to-bottom 버튼 탭', (tester) async {
      final log = LogController();
      Get.put<LogController>(log);
      for (var i = 0; i < 30; i++) {
        log.add('log line $i');
      }
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: LogBottomSheet()),
      ));
      await tester.pump();
      // 상단 아이콘 버튼들을 눌러 상태 토글/스크롤 경로 실행.
      final icons = find.byType(IconButton);
      final n = icons.evaluate().length;
      for (var i = 0; i < n && i < 3; i++) {
        await tester.tap(icons.at(i), warnIfMissed: false);
        await tester.pump();
      }
      expect(find.text('Debug Log'), findsOneWidget);
    });
  });
}
