import 'package:flutter/material.dart';

/// 4-Zone Launcher Layout — common template required by I-02 in the plan.
///
/// Layout reference (planning doc p.5):
///
///   ┌────────────────────────────────────────────────┐
///   │  Zone 1 — Top Bar (title / clock / status)    │  <- headerBuilder
///   ├──────────────┬─────────────────────────────────┤
///   │              │                                 │
///   │  Zone 2      │   Zone 3 — Main Content         │
///   │  Sidebar     │   (app cards / chat / details)  │  <- sidebar + main
///   │              │                                 │
///   ├──────────────┴─────────────────────────────────┤
///   │  Zone 4 — Always-pinned Prompt Input Bar       │  <- promptBar
///   └────────────────────────────────────────────────┘
///
/// Every screen in the launcher (main, per-app view) should use this layout
/// so UX invariants such as the bottom prompt bar and left sidebar hold
/// across app transitions.
class FourZoneLayout extends StatelessWidget {
  const FourZoneLayout({
    super.key,
    required this.sidebar,
    required this.main,
    required this.promptBar,
    this.topBar,
    this.sidebarWidth = 180,
    this.backgroundColor = const Color(0xFF0F172A),
  });

  /// Zone 1 — optional top bar. When null, the layout hides the zone.
  final PreferredSizeWidget? topBar;

  /// Zone 2 — vertical app sidebar.
  final Widget sidebar;

  /// Zone 3 — main content area.
  final Widget main;

  /// Zone 4 — bottom prompt input bar (always visible).
  final Widget promptBar;

  final double sidebarWidth;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: topBar,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Zone 2
                  SizedBox(
                    key: const Key('four_zone_sidebar'),
                    width: sidebarWidth,
                    child: Material(
                      color: const Color(0xFF111827),
                      child: sidebar,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFF1F2937)),
                  // Zone 3
                  Expanded(
                    child: Container(
                      key: const Key('four_zone_main'),
                      color: backgroundColor,
                      child: main,
                    ),
                  ),
                ],
              ),
            ),
            // Zone 4
            Container(
              key: const Key('four_zone_prompt'),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                border: Border(top: BorderSide(color: Color(0xFF1F2937))),
              ),
              child: SafeArea(top: false, child: promptBar),
            ),
          ],
        ),
      ),
    );
  }
}
