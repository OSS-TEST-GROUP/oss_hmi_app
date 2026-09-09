import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adsw_monitor/theme/adsw_palette.dart';

void main() {
  group('AdswPalette Tests', () {
    test('fromName returns correct palette', () {
      expect(AdswPalette.fromName('dark'), AdswPalette.dark);
      expect(AdswPalette.fromName('light'), AdswPalette.light);
      expect(AdswPalette.fromName('unknown'), AdswPalette.light);
      expect(AdswPalette.fromName(null), AdswPalette.light);
    });

    test('isDark property is accurate', () {
      expect(AdswPalette.dark.isDark, isTrue);
      expect(AdswPalette.light.isDark, isFalse);
    });

    test('toThemeData creates valid ThemeData for dark and light', () {
      final darkTheme = AdswPalette.dark.toThemeData();
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AdswPalette.dark.canvas);

      final lightTheme = AdswPalette.light.toThemeData();
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AdswPalette.light.canvas);
    });

    testWidgets('AdswPaletteScope provides palette in widget tree',
        (tester) async {
      late AdswPalette resolved;

      await tester.pumpWidget(
        AdswPaletteScope(
          palette: AdswPalette.dark,
          child: Builder(
            builder: (context) {
              resolved = AdswPaletteScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, AdswPalette.dark);
    });

    testWidgets('AdswPaletteScope fallback to notifier when no scope',
        (tester) async {
      late AdswPalette resolved;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = AdswPaletteScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(resolved, adswPaletteNotifier.value);
    });
  });
}
