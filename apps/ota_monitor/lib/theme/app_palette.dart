import 'package:flutter/material.dart';

/// Two-theme palette. Read from [palette] (a top-level getter that wraps
/// [paletteNotifier]). MaterialApp is wrapped in a ValueListenableBuilder
/// so the entire widget tree rebuilds when the user toggles themes.
class Palette {
  const Palette({
    required this.name,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textPlaceholder,
    required this.primary,
    required this.onPrimary,
    required this.accentBlue,
    required this.success,
    required this.warning,
    required this.error,
    required this.errorBg,
    required this.selectionBg,
    required this.selectionBorder,
    required this.actionGet,
    required this.actionSet,
    required this.actionRefresh,
    required this.actionDanger,
  });

  final String name;
  final Brightness brightness;

  // Surfaces
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color divider;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textPlaceholder;

  // Brand
  final Color primary;
  final Color onPrimary;
  final Color accentBlue;

  // Semantic status
  final Color success;
  final Color warning;
  final Color error;
  final Color errorBg;

  // Selected row highlight
  final Color selectionBg;
  final Color selectionBorder;

  // Action button colors (collapse to primary blue in light/Tesla)
  final Color actionGet;
  final Color actionSet;
  final Color actionRefresh;
  final Color actionDanger;

  /// Current OTA Monitor dark theme — keeps the existing palette.
  static const Palette dark = Palette(
    name: 'dark',
    brightness: Brightness.dark,
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceAlt: Color(0xFF111827),
    divider: Color(0xFF374151),
    textPrimary: Colors.white,
    textSecondary: Color(0xFFCBD5E1),
    textTertiary: Color(0xFF9CA3AF),
    textPlaceholder: Color(0xFF6B7280),
    primary: Color(0xFF3B82F6),
    onPrimary: Colors.white,
    accentBlue: Color(0xFF60A5FA),
    success: Color(0xFF34D399),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    errorBg: Color(0xFFB45309),
    selectionBg: Color(0xFF1E40AF),
    selectionBorder: Color(0xFF3B82F6),
    actionGet: Color(0xFF6366F1),
    actionSet: Color(0xFF0EA5E9),
    actionRefresh: Color(0xFF8B5CF6),
    actionDanger: Color(0xFFEF4444),
  );

  /// Tesla-inspired light theme. Single chromatic color (Electric Blue),
  /// flat surfaces, no shadows (handled at widget level), Carbon Dark text.
  static const Palette light = Palette(
    name: 'light',
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F4F4),
    divider: Color(0xFFEEEEEE),
    textPrimary: Color(0xFF171A20),
    textSecondary: Color(0xFF393C41),
    textTertiary: Color(0xFF5C5E62),
    textPlaceholder: Color(0xFF8E8E8E),
    primary: Color(0xFF3E6AE1),
    onPrimary: Colors.white,
    accentBlue: Color(0xFF3E6AE1),
    success: Color(0xFF15803D),
    warning: Color(0xFFD97706),
    error: Color(0xFFB91C1C),
    errorBg: Color(0xFFFEE2E2),
    selectionBg: Color(0xFFE0E7FF),
    selectionBorder: Color(0xFF3E6AE1),
    actionGet: Color(0xFF3E6AE1),
    actionSet: Color(0xFF3E6AE1),
    actionRefresh: Color(0xFF3E6AE1),
    actionDanger: Color(0xFFB91C1C),
  );

  static Palette fromName(String? name) {
    switch (name) {
      case 'dark':
        return Palette.dark;
      case 'light':
      default:
        return Palette.light;
    }
  }

  /// Build a Material ThemeData that matches this palette so widgets that
  /// use Theme.of(context) (TextField, Dialog, SnackBar) pick up the
  /// right colors automatically.
  ThemeData toThemeData() {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: accentBlue,
        onSecondary: onPrimary,
        error: error,
        onError: onPrimary,
        surface: surface,
        onSurface: textPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Top-level notifier — change `paletteNotifier.value` to swap themes
/// app-wide. Default is Tesla light (per user choice).
final ValueNotifier<Palette> paletteNotifier =
    ValueNotifier<Palette>(Palette.light);

/// Convenience getter for use inside `build()` methods. Because the root
/// MaterialApp is wrapped in a ValueListenableBuilder over the notifier,
/// any rebuild caused by a theme change propagates the new palette to
/// every widget that reads this getter.
Palette get palette => paletteNotifier.value;
