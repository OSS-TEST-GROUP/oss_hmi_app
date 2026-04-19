import 'package:flutter/material.dart';

import 'domain/plugin_registry.dart';
import 'presentation/shell/launcher_shell.dart';
import 'presentation/theme/launcher_tokens.dart';

/// Semver string of this launcher build. Compared against manifest
/// `min_launcher` to decide plugin compatibility.
const String launcherVersion = '4.0.0';

/// Root of the `apps/` tree the registry scans at startup. Relative to the
/// launcher process's current working directory; adjust when the launcher
/// is packaged as an AGL bundle.
const String appsRoot = 'apps';

void main() {
  runApp(const HmiLauncherApp());
}

class HmiLauncherApp extends StatelessWidget {
  const HmiLauncherApp({super.key, this.initialRegistry});

  /// Allows tests to inject a fixture registry so the UI doesn't depend on
  /// a real filesystem.
  final PluginRegistry? initialRegistry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGL Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: LauncherTokens.bg1,
        colorScheme: ColorScheme.dark(
          primary: LauncherTokens.launcher,
          secondary: LauncherTokens.t2,
        ),
      ),
      home: LauncherHomePage(initialRegistry: initialRegistry),
    );
  }
}

class LauncherHomePage extends StatefulWidget {
  const LauncherHomePage({super.key, this.initialRegistry});

  final PluginRegistry? initialRegistry;

  @override
  State<LauncherHomePage> createState() => _LauncherHomePageState();
}

class _LauncherHomePageState extends State<LauncherHomePage> {
  late final PluginRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = widget.initialRegistry ??
        PluginRegistryScanner(
          appsRoot: appsRoot,
          launcherVersion: launcherVersion,
        ).scan();
  }

  @override
  Widget build(BuildContext context) {
    return LauncherShell(
      registry: _registry,
    );
  }
}
