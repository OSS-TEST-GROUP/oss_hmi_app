import 'package:flutter/material.dart';

import '../data/lifecycle_data.dart';

/// Minimal dark palette for lfc_monitor. Mirrors adsw_monitor's "monitor card
/// over very-dark background" feel but stays self-contained so the launcher
/// can override per-plugin if needed.
class LfcPalette {
  const LfcPalette({
    this.background = const Color(0xFF111418),
    this.panel = const Color(0xFF1B1F26),
    this.panelBorder = const Color(0xFF2C3038),
    this.text = const Color(0xFFE6E8EB),
    this.subtext = const Color(0xFFA0A6AE),
    this.accent = const Color(0xFF5CC8FF),
  });

  final Color background;
  final Color panel;
  final Color panelBorder;
  final Color text;
  final Color subtext;
  final Color accent;

  static const defaults = LfcPalette();
}

/// Color hint for a given lifecycle state.  Single source of truth so both
/// service cards and event timeline render consistently.
Color stateColor(ServiceState s, LfcPalette p) {
  switch (s) {
    case ServiceState.running:
      return const Color(0xFF4CAF50);
    case ServiceState.initializing:
      return const Color(0xFFFFC107);
    case ServiceState.runningNoResponse:
      return const Color(0xFFFF9800);
    case ServiceState.terminating:
      return const Color(0xFF9C27B0);
    case ServiceState.notRunning:
      return const Color(0xFFF44336);
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
      return const Color(0xFF4CAF50);
    case ContainerState.paused:
      return const Color(0xFFFFC107);
    case ContainerState.stopped:
      return const Color(0xFFF44336);
    case ContainerState.unknownState:
      return p.subtext;
  }
}
