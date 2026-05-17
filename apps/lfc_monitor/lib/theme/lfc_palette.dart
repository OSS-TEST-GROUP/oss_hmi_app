import 'package:flutter/material.dart';

import '../data/lifecycle_data.dart';

/// F014: two-theme palette. The full widget tree rebuilds when the user
/// flips themes via Settings — MaterialApp wraps a ValueListenableBuilder
/// over [paletteNotifier]. Read inside `build()` via the top-level
/// [palette] getter (or pass-through props for tests / launcher embed).
class LfcPalette {
  const LfcPalette({
    required this.name,
    required this.brightness,
    required this.background,
    required this.panel,
    required this.panelBorder,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.errorBg,
    required this.textPlaceholder,
  });

  final String name;
  final Brightness brightness;

  // Core surfaces (used by the existing panels)
  final Color background;
  final Color panel;
  final Color panelBorder;

  // Text scale
  final Color text;
  final Color subtext;
  final Color textPlaceholder;

  // Accents / status
  final Color accent;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color errorBg;

  /// Dark theme — preserves the F012 baseline so the existing
  /// LfcPalette.defaults colors keep their look on a dark surface.
  static const LfcPalette dark = LfcPalette(
    name: 'dark',
    brightness: Brightness.dark,
    background: Color(0xFF111418),
    panel: Color(0xFF1B1F26),
    panelBorder: Color(0xFF2C3038),
    text: Color(0xFFE6E8EB),
    subtext: Color(0xFFA0A6AE),
    accent: Color(0xFF5CC8FF),
    divider: Color(0xFF2C3038),
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFFC107),
    error: Color(0xFFF44336),
    errorBg: Color(0xFF4B1E1E),
    textPlaceholder: Color(0xFF6B7280),
  );

  /// Tesla-inspired light theme — matches ota_monitor's light palette
  /// closely so a launcher-embedded session feels consistent across apps.
  static const LfcPalette light = LfcPalette(
    name: 'light',
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    panel: Color(0xFFFFFFFF),
    panelBorder: Color(0xFFE5E7EB),
    text: Color(0xFF171A20),
    subtext: Color(0xFF5C5E62),
    accent: Color(0xFF3E6AE1),
    divider: Color(0xFFEEEEEE),
    success: Color(0xFF15803D),
    warning: Color(0xFFD97706),
    error: Color(0xFFB91C1C),
    errorBg: Color(0xFFFEE2E2),
    textPlaceholder: Color(0xFF8E8E8E),
  );

  /// Existing alias — code that imported `LfcPalette.defaults` from the
  /// F012 baseline keeps working. Default kept as dark to match the
  /// pre-F014 look out of the box.
  static const LfcPalette defaults = dark;

  static LfcPalette fromName(String? name) {
    switch (name) {
      case 'light':
        return LfcPalette.light;
      case 'dark':
      default:
        return LfcPalette.dark;
    }
  }

  /// MaterialApp theme so TextField / Dialog / SnackBar pick up matching
  /// colors automatically without per-widget overrides.
  ThemeData toThemeData() {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
        secondary: accent,
        onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
        error: error,
        onError: Colors.white,
        surface: panel,
        onSurface: text,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: subtext, fontSize: 14),
      ),
    );
  }
}

/// Top-level notifier — set `paletteNotifier.value = LfcPalette.xxx` to
/// swap themes app-wide. Default tracks the F012 dark look; loadConfig may
/// override it at startup from the `theme` field.
final ValueNotifier<LfcPalette> paletteNotifier =
    ValueNotifier<LfcPalette>(LfcPalette.dark);

/// Convenience accessor inside `build()` methods. Wrapped via the root
/// MaterialApp's ValueListenableBuilder, so a notifier update rebuilds
/// every widget that reads this getter.
LfcPalette get palette => paletteNotifier.value;

/// Color hint for a given lifecycle state.  Single source of truth so both
/// service cards and event timeline render consistently.
Color stateColor(ServiceState s, LfcPalette p) {
  switch (s) {
    case ServiceState.running:
      return p.success;
    case ServiceState.initializing:
      return p.warning;
    case ServiceState.runningNoResponse:
      return const Color(0xFFFF9800);
    case ServiceState.terminating:
      return const Color(0xFF9C27B0);
    case ServiceState.notRunning:
      return p.error;
    case ServiceState.unknown:
      return p.subtext;
  }
}

/// F013: container-state hint, intentionally close to service stateColor so
/// the two badges look related but reuses dedicated values for the new
/// states (paused has no service-side counterpart).
Color containerStateColor(ContainerState s, LfcPalette p) {
  switch (s) {
    case ContainerState.running:
      return p.success;
    case ContainerState.paused:
      return p.warning;
    case ContainerState.stopped:
      return p.error;
    case ContainerState.unknownState:
      return p.subtext;
  }
}
