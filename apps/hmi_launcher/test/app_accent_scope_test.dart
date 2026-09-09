// QA(docs/qa): AppAccentScope(InheritedWidget) + AppPlaceholderPanel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/presentation/theme/app_accent_scope.dart';
import 'package:hmi_launcher/presentation/panels/app_placeholder_panel.dart';

void main() {
  testWidgets('of() 는 가장 가까운 scope 의 accent 반환', (tester) async {
    late Color seen;
    await tester.pumpWidget(MaterialApp(
      home: AppAccentScope(
        accentColor: const Color(0xFF112233),
        child: Builder(builder: (ctx) {
          seen = AppAccentScope.of(ctx);
          return const SizedBox();
        }),
      ),
    ));
    expect(seen, const Color(0xFF112233));
  });

  testWidgets('maybeOf() 는 scope 없으면 null', (tester) async {
    Color? seen = const Color(0xFFFFFFFF);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        seen = AppAccentScope.maybeOf(ctx);
        return const SizedBox();
      }),
    ));
    expect(seen, isNull);
  });

  testWidgets('maybeOf() 는 scope 있으면 색 반환', (tester) async {
    Color? seen;
    await tester.pumpWidget(MaterialApp(
      home: AppAccentScope(
        accentColor: const Color(0xFFAABBCC),
        child: Builder(builder: (ctx) {
          seen = AppAccentScope.maybeOf(ctx);
          return const SizedBox();
        }),
      ),
    ));
    expect(seen, const Color(0xFFAABBCC));
  });

  test('updateShouldNotify: 색 다르면 true, 같으면 false', () {
    const a = AppAccentScope(
        accentColor: Color(0xFF000000), child: SizedBox());
    const b = AppAccentScope(
        accentColor: Color(0xFFFFFFFF), child: SizedBox());
    const c = AppAccentScope(
        accentColor: Color(0xFF000000), child: SizedBox());
    expect(a.updateShouldNotify(b), isTrue);
    expect(a.updateShouldNotify(c), isFalse);
  });

  testWidgets('AppPlaceholderPanel 렌더', (tester) async {
    final app = AppManifest(
      id: 'x', name: 'X App', icon: '🚀', version: '1.0.0',
      entry: 'x/main.dart', prompts: const [],
    );
    await tester.pumpWidget(MaterialApp(
      home: AppAccentScope(
        accentColor: const Color(0xFF6366F1),
        child: Scaffold(body: AppPlaceholderPanel(app: app)),
      ),
    ));
    expect(find.byKey(const Key('app_panel_x')), findsOneWidget);
    expect(find.byKey(const Key('app_placeholder_x')), findsOneWidget);
    expect(find.text('X App is being prepared'), findsOneWidget);
    expect(find.text('🚀'), findsOneWidget);
  });
}
