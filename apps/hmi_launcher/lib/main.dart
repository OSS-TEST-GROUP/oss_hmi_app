import 'package:flutter/material.dart';

import 'presentation/layout/four_zone_layout.dart';

void main() {
  runApp(const HmiLauncherApp());
}

class HmiLauncherApp extends StatelessWidget {
  const HmiLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF64748B),
        ),
      ),
      home: const LauncherHomePage(),
    );
  }
}

/// Launcher home page. For L002 this is intentionally a minimal skeleton
/// that proves the 4-Zone layout renders; L003/L004 will replace the
/// placeholder sidebar, main and prompt bar with real widgets wired to
/// the Plugin Registry.
class LauncherHomePage extends StatelessWidget {
  const LauncherHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FourZoneLayout(
      topBar: const _LauncherTopBar(),
      sidebar: const _PlaceholderSidebar(),
      main: const _PlaceholderMain(),
      promptBar: const _PlaceholderPromptBar(),
    );
  }
}

class _LauncherTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _LauncherTopBar();

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF111827),
      elevation: 0,
      title: const Text(
        'AGL Launcher',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              'v0.1.0 · MVP',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderSidebar extends StatelessWidget {
  const _PlaceholderSidebar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'Sidebar\n(L004)',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
    );
  }
}

class _PlaceholderMain extends StatelessWidget {
  const _PlaceholderMain();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Main content area (L004)\nAppLaunchCard / chat / details will render here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
    );
  }
}

class _PlaceholderPromptBar extends StatelessWidget {
  const _PlaceholderPromptBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        'Prompt input bar (L004) — always pinned',
        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
    );
  }
}
