import 'package:flutter/material.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Status level enum for status indicator.
enum StatusLevel { ok, warn, error, off }

/// Status bar widget with app name, status indicator, and time.
/// Height: 40px (fixed via LauncherTokens.statusbarHeight).
class LauncherStatusBar extends StatelessWidget {
  const LauncherStatusBar({
    super.key,
    required this.appName,
    this.statusText = 'Vehicle OK',
    this.statusLevel = StatusLevel.ok,
  });

  final String appName;
  final String statusText;
  final StatusLevel statusLevel;

  Color _getStatusColor() {
    switch (statusLevel) {
      case StatusLevel.ok:
        return LauncherTokens.ok;
      case StatusLevel.warn:
        return LauncherTokens.warn;
      case StatusLevel.error:
        return LauncherTokens.error;
      case StatusLevel.off:
        return LauncherTokens.off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);
    final statusColor = _getStatusColor();

    return Container(
      key: const Key('launcher_statusbar'),
      height: LauncherTokens.statusbarHeight,
      decoration: BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(
          bottom: BorderSide(
            color: accent,
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Text(
            appName,
            key: const Key('statusbar_app_name'),
            style: TextStyle(
              fontFamily: LauncherTokens.fontDisplay,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 16,
            color: LauncherTokens.b2,
          ),
          const SizedBox(width: 12),
          Container(
            key: const Key('statusbar_status_dot'),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.8),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            key: const Key('statusbar_status_text'),
            style: TextStyle(
              fontFamily: LauncherTokens.fontMono,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
          const Spacer(),
          _TimeDisplay(key: const Key('statusbar_time')),
        ],
      ),
    );
  }
}

/// Real-time clock display.
class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({super.key});

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    return Text(
      _formatTime(),
      style: TextStyle(
        fontFamily: LauncherTokens.fontMono,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: accent,
      ),
    );
  }
}
