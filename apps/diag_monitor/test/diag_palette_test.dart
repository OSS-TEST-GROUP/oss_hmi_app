import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diag_monitor/theme/diag_palette.dart';

void main() {
  group('DiagPalette Tests', () {
    test('fromName returns correct palette', () {
      expect(DiagPalette.fromName('dark'), DiagPalette.dark);
      expect(DiagPalette.fromName('light'), DiagPalette.light);
      expect(DiagPalette.fromName('unknown'), DiagPalette.light);
      expect(DiagPalette.fromName(null), DiagPalette.light);
    });

    test('isDark property is accurate', () {
      expect(DiagPalette.dark.isDark, isTrue);
      expect(DiagPalette.light.isDark, isFalse);
    });

    test('toThemeData creates valid ThemeData for dark and light', () {
      final darkTheme = DiagPalette.dark.toThemeData();
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, DiagPalette.dark.canvas);

      final lightTheme = DiagPalette.light.toThemeData();
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, DiagPalette.light.canvas);
    });

    testWidgets('DiagPaletteScope provides palette in widget tree',
        (tester) async {
      late DiagPalette resolved;

      await tester.pumpWidget(
        DiagPaletteScope(
          palette: DiagPalette.dark,
          child: Builder(
            builder: (context) {
              resolved = DiagPaletteScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, DiagPalette.dark);
    });

    testWidgets('DiagPaletteScope fallback to notifier when no scope',
        (tester) async {
      late DiagPalette resolved;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = DiagPaletteScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolved, diagPaletteNotifier.value);
    });
  });
}
