import 'dart:ui';

/// Design tokens extracted from AGL_Launcher_Design_v2.html CSS variables.
/// All values are const to enable tree-shaking and compile-time optimization.
abstract final class LauncherTokens {
  // ── Background Layers ──
  static const Color bg0 = Color(0xFF040810); // deepest
  static const Color bg1 = Color(0xFF060C16); // app background
  static const Color bg2 = Color(0xFF09111F); // panel
  static const Color bg3 = Color(0xFF0D1828); // card
  static const Color bg4 = Color(0xFF121F34); // hover

  // ── Borders ──
  static const Color b1 = Color(0xFF1A2D45);
  static const Color b2 = Color(0xFF243D5C);

  // ── Text ──
  static const Color t1 = Color(0xFFC8E0FF); // primary
  static const Color t2 = Color(0xFF6A90B8); // secondary
  static const Color t3 = Color(0xFF3A5572); // tertiary/hint

  // ── App Accent Colors ──
  static const Color launcher = Color(0xFF00D4FF);
  static const Color adsw = Color(0xFF00E5A0);
  static const Color ota = Color(0xFFF5C400);
  static const Color rviz = Color(0xFFE060FF);

  // ── Status Colors ──
  static const Color ok = Color(0xFF00D97E);
  static const Color warn = Color(0xFFF5A800);
  static const Color error = Color(0xFFF53060);
  static const Color info = Color(0xFF4A9EFF);
  static const Color off = Color(0xFF3A5572);

  // ── Fixed Dimensions ──
  static const double titlebarHeight = 30.0;
  static const double statusbarHeight = 40.0;
  static const double promptbarHeight = 60.0;
  static const double sidebarWidth = 188.0;

  // ── Typography (font families) ──
  static const String fontDisplay = 'Orbitron';
  static const String fontMono = 'JetBrainsMono';
  static const String fontBody = 'NotoSansKR';

  // ── Traffic Light Dots ──
  static const Color dotRed = Color(0xFFFF5F57);
  static const Color dotYellow = Color(0xFFFFBD2E);
  static const Color dotGreen = Color(0xFF28C840);
}
