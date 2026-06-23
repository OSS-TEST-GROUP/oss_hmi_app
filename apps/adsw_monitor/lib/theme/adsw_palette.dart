import 'package:flutter/material.dart';

class AdswPalette {
  const AdswPalette({
    required this.name,
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.placeholder,
    required this.line,
    required this.primary,
    required this.primaryText,
    required this.valueSurface,
  });

  final String name;
  final Brightness brightness;
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color muted;
  final Color placeholder;
  final Color line;
  final Color primary;
  final Color primaryText;
  final Color valueSurface;

  bool get isDark => brightness == Brightness.dark;

  static const light = AdswPalette(
    name: 'light',
    brightness: Brightness.light,
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F4),
    surfaceAlt: Color(0xFFFFFFFF),
    text: Color(0xFF171A20),
    muted: Color(0xFF5C5E62),
    placeholder: Color(0xFF8E8E8E),
    line: Color(0xFFE5E5E5),
    primary: Color(0xFF3E6AE1),
    primaryText: Color(0xFFFFFFFF),
    valueSurface: Color(0xFFFFFFFF),
  );

  static const dark = AdswPalette(
    name: 'dark',
    brightness: Brightness.dark,
    canvas: Color(0xFF171A20),
    surface: Color(0xFF22252B),
    surfaceAlt: Color(0xFF111317),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFFD0D1D2),
    placeholder: Color(0xFF8E8E8E),
    line: Color(0xFF393C41),
    primary: Color(0xFF3E6AE1),
    primaryText: Color(0xFFFFFFFF),
    valueSurface: Color(0xFF171A20),
  );

  static AdswPalette fromName(String? name) {
    return name == 'dark' ? dark : light;
  }

  ThemeData toThemeData() {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: primaryText,
        secondary: primary,
        onSecondary: primaryText,
        error: const Color(0xFFB74134),
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const ['NotoSansKR'],
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const ['NotoSansKR'],
      ),
      iconTheme: IconThemeData(color: text),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceAlt,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        contentTextStyle: TextStyle(color: muted, fontSize: 14, height: 1.4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryText,
        unselectedLabelColor: muted,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

final ValueNotifier<AdswPalette> adswPaletteNotifier =
    ValueNotifier<AdswPalette>(AdswPalette.light);

class AdswPaletteScope extends InheritedWidget {
  const AdswPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final AdswPalette palette;

  static AdswPalette of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AdswPaletteScope>();
    return scope?.palette ?? adswPaletteNotifier.value;
  }

  @override
  bool updateShouldNotify(AdswPaletteScope oldWidget) =>
      palette != oldWidget.palette;
}
