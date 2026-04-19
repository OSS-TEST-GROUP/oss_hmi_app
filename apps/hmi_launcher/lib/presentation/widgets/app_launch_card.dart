import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Auto-generated "launch this app?" confirmation card (F-04 in the plan).
///
/// Rendered in the main zone after the NLU router resolves a manifest.
/// The card shows the app's icon, name, category-as-subtitle, and a single
/// primary button that fires [onLaunch].
///
/// v2 Redesign: Uses OutlinedButton with accent border, LauncherTokens colors,
/// and AppAccentScope for dynamic accent color.
class AppLaunchCard extends StatefulWidget {
  const AppLaunchCard({
    super.key,
    required this.app,
    required this.onLaunch,
  });

  final AppManifest app;
  final VoidCallback onLaunch;

  @override
  State<AppLaunchCard> createState() => _AppLaunchCardState();
}

class _AppLaunchCardState extends State<AppLaunchCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        key: Key('app_launch_card_${widget.app.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: LauncherTokens.bg3,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: accent, width: 3),
            top: BorderSide(color: LauncherTokens.b1),
            right: BorderSide(color: LauncherTokens.b1),
            bottom: BorderSide(color: LauncherTokens.b1),
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? accent.withOpacity(0.08)
                  : Colors.black.withOpacity(0.4),
              blurRadius: _isHovered ? 24 : 18,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              widget.app.icon,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.app.name,
                    style: TextStyle(
                      fontFamily: LauncherTokens.fontDisplay,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.app.category} · v${widget.app.version}',
                    style: TextStyle(
                      fontFamily: LauncherTokens.fontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: LauncherTokens.t2,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              key: Key('app_launch_button_${widget.app.id}'),
              onPressed: widget.onLaunch,
              style: OutlinedButton.styleFrom(
                backgroundColor: _isHovered ? accent : Colors.transparent,
                foregroundColor: _isHovered ? LauncherTokens.bg0 : accent,
                side: BorderSide(color: accent, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(
                'Launch',
                style: TextStyle(
                  fontFamily: LauncherTokens.fontDisplay,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
