import 'dart:ui';

/// Parses a CSS hex color string (e.g. `#2E6BE6` or `2E6BE6`) into a [Color].
///
/// Both files that previously duplicated this helper — `manage_apps_panel.dart`
/// and `launcher_bot_shell.dart` — now import this single implementation.
///
/// [fallback] is returned when [hex] cannot be parsed (wrong length or
/// non-hex characters).  Defaults to Electric Blue (`0xFF2E6BE6`).
Color parseHexColor(String hex, {Color fallback = const Color(0xFF2E6BE6)}) {
  final normalized = hex.replaceFirst('#', '');
  if (normalized.length != 6) return fallback;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
