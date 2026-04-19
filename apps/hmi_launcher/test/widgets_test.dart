import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmi_launcher/domain/app_manifest.dart';
import 'package:hmi_launcher/presentation/widgets/app_launch_card.dart';
import 'package:hmi_launcher/presentation/widgets/data_card.dart';
import 'package:hmi_launcher/presentation/widgets/prompt_input_bar.dart';
import 'package:hmi_launcher/presentation/widgets/sidebar_navigator.dart';
import 'package:hmi_launcher/presentation/theme/app_accent_scope.dart';
import 'package:hmi_launcher/presentation/theme/launcher_tokens.dart';

AppManifest _manifest(String id, {String name = 'Name', String icon = '📦'}) {
  return AppManifest(
    id: id,
    name: name,
    icon: icon,
    version: '1.0.0',
    entry: '$id/main.dart',
    prompts: ['open $id'],
    color: '#FCD34D',
  );
}

Widget _wrap(Widget child, {Size size = const Size(1200, 800)}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: AppAccentScope(
      accentColor: LauncherTokens.launcher,
      child: Scaffold(body: SizedBox(width: size.width, height: size.height, child: child)),
    ),
  );
}

void main() {
  group('SidebarNavigator', () {
    testWidgets('renders one item per registered app', (tester) async {
      final apps = [
        _manifest('ota_monitor', name: 'OTA Monitor'),
        _manifest('adsw_monitor', name: 'AD SW'),
      ];
      String? selected;
      await tester.pumpWidget(_wrap(
        SidebarNavigator(
          apps: apps,
          onAppSelected: (a) => selected = a.id,
        ),
      ));

      expect(find.byKey(const Key('sidebar_list')), findsOneWidget);
      expect(find.byKey(const Key('sidebar_item_ota_monitor')), findsOneWidget);
      expect(find.byKey(const Key('sidebar_item_adsw_monitor')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sidebar_item_ota_monitor')));
      expect(selected, 'ota_monitor');
    });
  });

  group('PromptInputBar', () {
    testWidgets('fires onSubmitted on enter and clears input', (tester) async {
      final ctrl = TextEditingController();
      String? captured;
      await tester.pumpWidget(_wrap(
        PromptInputBar(controller: ctrl, onSubmitted: (t) => captured = t),
      ));

      await tester.enterText(find.byKey(const Key('prompt_input_field')), 'OTA 모니터 열어줘');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(captured, 'OTA 모니터 열어줘');
      expect(ctrl.text, isEmpty);
    });

    testWidgets('ignores empty / whitespace-only submissions', (tester) async {
      final ctrl = TextEditingController(text: '   ');
      String? captured;
      await tester.pumpWidget(_wrap(
        PromptInputBar(controller: ctrl, onSubmitted: (t) => captured = t),
      ));

      await tester.tap(find.byKey(const Key('prompt_submit_button')));
      await tester.pump();

      expect(captured, isNull);
    });
  });

  group('AppLaunchCard', () {
    testWidgets('renders manifest info and fires onLaunch', (tester) async {
      final m = _manifest('ota_monitor', name: 'OTA Monitor');
      var launched = false;
      await tester.pumpWidget(_wrap(
        AppLaunchCard(app: m, onLaunch: () => launched = true),
      ));

      expect(find.text('OTA Monitor'), findsOneWidget);
      expect(find.text('Launch'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_launch_button_ota_monitor')));
      expect(launched, isTrue);
    });
  });

  group('DataCard', () {
    testWidgets('renders label / value / optional badge', (tester) async {
      await tester.pumpWidget(_wrap(
        const DataCard(label: 'Status', value: 'LATEST', badge: 'OK'),
      ));
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('LATEST'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('omits badge when not provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const DataCard(label: 'Status', value: 'LATEST'),
      ));
      expect(find.text('OK'), findsNothing);
    });
  });
}
