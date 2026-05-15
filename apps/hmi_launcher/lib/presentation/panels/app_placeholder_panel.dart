import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Placeholder panel for apps that will be embedded in L009.
class AppPlaceholderPanel extends StatelessWidget {
  const AppPlaceholderPanel({
    super.key,
    required this.app,
  });

  final AppManifest app;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    return Container(
      key: Key('app_panel_${app.id}'),
      color: LauncherTokens.bg1,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              app.icon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              '${app.name} is being prepared',
              key: Key('app_placeholder_${app.id}'),
              style: TextStyle(
                fontFamily: LauncherTokens.fontDisplay,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Plugin embedding will be implemented in L009',
              style: TextStyle(
                fontFamily: LauncherTokens.fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: LauncherTokens.t2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
