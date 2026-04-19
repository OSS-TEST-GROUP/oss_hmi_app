import 'package:flutter/material.dart';
import '../theme/launcher_tokens.dart';

/// Title bar widget with traffic light dots and centered title.
/// Height: 30px (fixed via LauncherTokens.titlebarHeight).
class LauncherTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const LauncherTitleBar({
    super.key,
    this.title = 'AGL Launcher v4.0 — Plugin Registry Architecture',
  });

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(LauncherTokens.titlebarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('launcher_titlebar'),
      height: LauncherTokens.titlebarHeight,
      decoration: BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(
          bottom: BorderSide(color: LauncherTokens.b1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0),
      child: Row(
        children: [
          _TrafficLightDot(
            key: const Key('titlebar_dot_red'),
            color: LauncherTokens.dotRed,
          ),
          const SizedBox(width: 8),
          _TrafficLightDot(
            key: const Key('titlebar_dot_yellow'),
            color: LauncherTokens.dotYellow,
          ),
          const SizedBox(width: 8),
          _TrafficLightDot(
            key: const Key('titlebar_dot_green'),
            color: LauncherTokens.dotGreen,
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                key: const Key('titlebar_title'),
                style: TextStyle(
                  fontFamily: LauncherTokens.fontMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: LauncherTokens.t3,
                  letterSpacing: 0.7,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 60), // Balance for dots on left
        ],
      ),
    );
  }
}

/// Traffic light dot widget with glow effect.
class _TrafficLightDot extends StatelessWidget {
  const _TrafficLightDot({
    super.key,
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 5,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}
