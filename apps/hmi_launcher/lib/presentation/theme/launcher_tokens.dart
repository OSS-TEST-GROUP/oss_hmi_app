import 'dart:ui';

/// Design tokens for the Tesla-reskin launcher shell.
///
/// Source: AGL Launcher design bundle (Tesla Design System reskin,
/// 2026-04-20). Monochrome canvas with a single Electric Blue accent.
/// Per-app tinting is intentionally dropped — the active accent is the
/// same Electric Blue everywhere, per the design spec.
abstract final class LauncherTokens {
  // ── Surfaces ──
  static const Color bg0 = Color(0xFFFFFFFF); // pure white (page)
  static const Color bg1 = Color(0xFFFFFFFF); // shell / app view
  static const Color bg2 = Color(0xFFFAFAFA); // rail / alt surface
  static const Color bg3 = Color(0xFFF4F4F4); // hover / soft surface
  static const Color bg4 = Color(0xFFEFEFEC); // active rail item

  // ── Borders ──
  static const Color b1 = Color(0xFFEEEEEE); // subtle divider
  static const Color b2 = Color(0xFFD0D1D2); // ui border

  // ── Text ──
  static const Color t1 = Color(0xFF171A20); // primary (carbon)
  static const Color t2 = Color(0xFF393C41); // body (graphite)
  static const Color t3 = Color(0xFF5C5E62); // tertiary (pewter)
  static const Color tHint = Color(0xFF8E8E8E); // placeholder (silver fog)

  // ── Accent (Electric Blue — primary CTA only) ──
  static const Color accent = Color(0xFF3E6AE1);
  static const Color accentHover = Color(0xFF3457C2);
  static const Color accentCarbon = Color(0xFF171A20);

  // ── Status (monochrome, blue for active) ──
  static const Color ok = Color(0xFF3E6AE1);
  static const Color warn = Color(0xFF171A20);
  static const Color error = Color(0xFF171A20);
  static const Color info = Color(0xFF3E6AE1);
  static const Color off = Color(0xFFD0D1D2);

  // Legacy per-app accent aliases. AppAccentScope still exists but always
  // resolves to Electric Blue in Tesla mode.
  static const Color launcher = accent;
  static const Color adsw = accent;
  static const Color ota = accent;
  static const Color rviz = accent;

  // ── Dimensions ──
  static const double titlebarHeight = 56.0;
  static const double statusbarHeight = 0.0; // deprecated in Tesla layout
  static const double promptbarHeight = 60.0;
  static const double sidebarWidth = 220.0;

  // ── Typography ──
  // Inter is the design intent; not bundled, so Flutter falls back to the
  // platform's default sans-serif. Keep the string to document intent.
  static const String fontDisplay = 'Inter';
  static const String fontBody = 'Inter';
  static const String fontMono = 'JetBrainsMono';

  // ── Legacy compat (traffic-light dots from v2) ──
  // Retained only so in-flight imports keep compiling. Unused by Tesla shell.
  static const Color dotRed = Color(0xFFFF5F57);
  static const Color dotYellow = Color(0xFFFFBD2E);
  static const Color dotGreen = Color(0xFF28C840);
}
