import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../app_icon.dart';
import '../theme/launcher_tokens.dart';

/// Tesla-style left rail.
///
/// Sentence-case labels, 14/500, active item = left 3px blue marker
/// + `bg4` background. Small line icons render as affordances, not
/// decoration. Home entry is always first; plugin apps follow.
class LauncherSidebar extends StatelessWidget {
  const LauncherSidebar({
    super.key,
    required this.apps,
    required this.selectedAppId,
    required this.onAppSelected,
    this.connected = true,
    this.hostLabel = 'agl-ivi-01',
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<String?> onAppSelected;
  final bool connected;
  final String hostLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('launcher_sidebar'),
      width: LauncherTokens.sidebarWidth,
      decoration: const BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(right: BorderSide(color: LauncherTokens.b1)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'APPS',
              key: Key('sidebar_section_label'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: LauncherTokens.tHint,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _RailItem(
            key: const Key('sidebar_item_home'),
            label: 'Launcher',
            icon: Icons.home_outlined,
            isActive: selectedAppId == null,
            onTap: () => onAppSelected(null),
          ),
          for (final app in apps)
            _RailItem(
              key: Key('sidebar_item_${app.id}'),
              label: app.name,
              icon: LauncherAppIcons.forApp(app),
              isActive: selectedAppId == app.id,
              onTap: () => onAppSelected(app.id),
            ),
          const Spacer(),
          _RailFoot(connected: connected, hostLabel: hostLabel),
        ],
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? LauncherTokens.bg4
        : (_hover ? const Color(0xFFF0EFEC) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 330),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? LauncherTokens.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                widget.icon,
                size: 16,
                color: widget.isActive ? LauncherTokens.t1 : LauncherTokens.t2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: LauncherTokens.fontBody,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        widget.isActive ? LauncherTokens.t1 : LauncherTokens.t2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailFoot extends StatelessWidget {
  const _RailFoot({required this.connected, required this.hostLabel});

  final bool connected;
  final String hostLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LauncherTokens.b1)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? LauncherTokens.accent : LauncherTokens.off,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connected ? 'AGL connected' : 'Disconnected',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: LauncherTokens.t1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hostLabel,
            style: const TextStyle(
              fontSize: 11,
              color: LauncherTokens.tHint,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
