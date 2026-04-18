// Smoke tests for the 4-Zone launcher scaffold (L002).
//
// These tests verify that:
//   1. HmiLauncherApp boots without throwing.
//   2. All four zones are present in the widget tree (identified by Key).
//   3. Basic branding strings render.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/main.dart';
import 'package:hmi_launcher/presentation/layout/four_zone_layout.dart';

void main() {
  testWidgets('HmiLauncherApp renders the four zones', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HmiLauncherApp());

    expect(find.byType(FourZoneLayout), findsOneWidget);
    expect(find.byKey(const Key('four_zone_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('four_zone_main')), findsOneWidget);
    expect(find.byKey(const Key('four_zone_prompt')), findsOneWidget);

    // Branding strings from L002 placeholders
    expect(find.text('AGL Launcher'), findsOneWidget);
    expect(find.text('v0.1.0 · MVP'), findsOneWidget);
  });

  testWidgets('FourZoneLayout renders injected widgets in each zone',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FourZoneLayout(
          sidebar: Text('SIDEBAR-X'),
          main: Text('MAIN-X'),
          promptBar: Text('PROMPT-X'),
        ),
      ),
    );

    expect(find.text('SIDEBAR-X'), findsOneWidget);
    expect(find.text('MAIN-X'), findsOneWidget);
    expect(find.text('PROMPT-X'), findsOneWidget);
  });
}
