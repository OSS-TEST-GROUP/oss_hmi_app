import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/view/log_overlay.dart';

void main() {
  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('LogController & LogBottomSheet', () {
    test('LogController adds lines and respects maxLines', () {
      final ctrl = LogController(maxLines: 5);
      expect(ctrl.lines.isEmpty, isTrue);

      ctrl.add('line 1');
      ctrl.add('line 2');
      expect(ctrl.lines.length, 2);
      expect(ctrl.lines.first, 'line 1');

      for (int i = 3; i <= 10; i++) {
        ctrl.add('line $i');
      }
      expect(ctrl.lines.length, 5);
      expect(ctrl.lines.last, 'line 10');

      ctrl.clear();
      expect(ctrl.lines.isEmpty, isTrue);
    });

    testWidgets('LogBottomSheet renders empty state and logs when added',
        (tester) async {
      final ctrl = Get.put(LogController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LogBottomSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Debug Log'), findsOneWidget);
      expect(find.text('No logs yet...'), findsOneWidget);

      ctrl.add('Test Log Message 1');
      ctrl.add('Test Log Message 2');
      await tester.pumpAndSettle();

      expect(find.text('Test Log Message 1'), findsOneWidget);
      expect(find.text('Test Log Message 2'), findsOneWidget);

      // Clear button
      final clearBtn = find.byTooltip('Clear');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('No logs yet...'), findsOneWidget);
    });

    testWidgets('LogBottomSheet toggles auto-follow and jump bottom',
        (tester) async {
      final ctrl = Get.put(LogController());
      for (int i = 0; i < 30; i++) {
        ctrl.add('Long log item $i');
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LogBottomSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFollow = find.byTooltip('Auto-follow: ON');
      expect(toggleFollow, findsOneWidget);
      await tester.tap(toggleFollow);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Auto-follow: OFF'), findsOneWidget);

      final jumpBottom = find.byTooltip('Jump bottom');
      expect(jumpBottom, findsOneWidget);
      await tester.tap(jumpBottom);
      await tester.pumpAndSettle();
    });

    test('runWithLogCapture captures print and errors into LogController', () async {
      runWithLogCapture(() {
        debugPrint('Captured debug print line');
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final ctrl = Get.find<LogController>();
      expect(ctrl.lines.isNotEmpty, isTrue);
      ctrl.onClose();
    });
  });
}
