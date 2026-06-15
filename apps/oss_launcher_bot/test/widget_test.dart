import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oss_launcher_bot/app.dart';

void main() {
  // Boot smoke: the full launcher app (incl. the Gemma chatbot service +
  // responsive shell) builds and mounts a MaterialApp without throwing.
  //
  // Deep surface/interaction coverage lives in the focused suites
  // (quick_prompt_bar_test, virtual_keyboard_test, gemma_metrics_test) which
  // exercise widgets in isolation — far more stable headless than asserting
  // the full async dashboard render here.
  testWidgets('launcher bot app boots and mounts a MaterialApp',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
