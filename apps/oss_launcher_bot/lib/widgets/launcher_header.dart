import 'package:flutter/material.dart';

class LauncherHeader extends StatelessWidget {
  const LauncherHeader({
    super.key,
    required this.compact,
    required this.onMetricsTap,
  });

  final bool compact;
  final VoidCallback onMetricsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 132 : 180,
            child: const Text(
              'LAUNCHER',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF171A20),
                letterSpacing: 4,
              ),
            ),
          ),
          if (!compact)
            const Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavLabel('Chat'),
                  _NavLabel('Navigation'),
                  _NavLabel('Media'),
                  _NavLabel('Phone'),
                  _NavLabel('Apps'),
                ],
              ),
            )
          else
            const Spacer(),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderIcon(icon: Icons.help_outline_rounded),
              SizedBox(width: 4),
              _HeaderIcon(icon: Icons.language_rounded),
              SizedBox(width: 4),
            ],
          ),
          _HeaderIcon(
            icon: Icons.monitor_heart_outlined,
            onPressed: onMetricsTap,
          ),
        ],
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF171A20),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(label),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () {},
      icon: Icon(icon),
      color: const Color(0xFF171A20),
      iconSize: 20,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
