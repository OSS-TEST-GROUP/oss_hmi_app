import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Sidebar navigation widget with logo, nav items, add button, and connection indicator.
/// Width: 188px (fixed via LauncherTokens.sidebarWidth).
class LauncherSidebar extends StatelessWidget {
  const LauncherSidebar({
    super.key,
    required this.apps,
    required this.selectedAppId,
    required this.onAppSelected,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<String?> onAppSelected;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    return Container(
      key: const Key('launcher_sidebar'),
      width: LauncherTokens.sidebarWidth,
      decoration: BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(right: BorderSide(color: LauncherTokens.b1)),
      ),
      child: Stack(
        children: [
          // Glow line at top
          Positioned(
            key: const Key('sidebar_glow_line'),
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    accent.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              _LogoBlock(key: const Key('sidebar_logo')),
              _NavSectionLabel(
                key: const Key('sidebar_home_label'),
                label: 'HOME',
              ),
              _NavItem(
                key: const Key('sidebar_home_item'),
                icon: '🏠',
                text: 'Home / Launcher',
                isActive: selectedAppId == null,
                accentColor: accent,
                onTap: () => onAppSelected(null),
              ),
              _NavSectionLabel(
                key: const Key('sidebar_apps_label'),
                label: 'APPS',
                topMargin: 6,
              ),
              ...apps.map((app) => _NavItem(
                    key: Key('sidebar_nav_${app.id}'),
                    icon: app.icon,
                    text: app.name,
                    isActive: selectedAppId == app.id,
                    accentColor: accent,
                    onTap: () => onAppSelected(app.id),
                  )),
              const Spacer(),
              _AddButton(key: const Key('sidebar_add_button')),
              _ConnectionIndicator(key: const Key('sidebar_connection_indicator')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Logo block with icon and version info.
class _LogoBlock extends StatelessWidget {
  const _LogoBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: LauncherTokens.b1)),
      ),
      child: Row(
        children: [
          Container(
            key: const Key('logo_icon'),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.2),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: TextStyle(
                fontFamily: LauncherTokens.fontDisplay,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LauncherTokens.bg0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AGL Launcher',
                  style: TextStyle(
                    fontFamily: LauncherTokens.fontDisplay,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LauncherTokens.t1,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v4.0 · Plugin Registry',
                  style: TextStyle(
                    fontFamily: LauncherTokens.fontMono,
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    color: LauncherTokens.t3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label for nav groups.
class _NavSectionLabel extends StatelessWidget {
  const _NavSectionLabel({
    super.key,
    required this.label,
    this.topMargin = 0,
  });

  final String label;
  final double topMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10 + topMargin, 14, 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: LauncherTokens.fontMono,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: LauncherTokens.t3,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Navigation item widget.
class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.text,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  final String icon;
  final String text;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: (widget.isActive || _isHovered)
                ? LauncherTokens.bg4
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: widget.isActive
                    ? widget.accentColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  widget.icon,
                  style: const TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontFamily: LauncherTokens.fontBody,
                    fontSize: 12,
                    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    color: widget.isActive ? widget.accentColor : LauncherTokens.t2,
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

/// Add app button.
class _AddButton extends StatelessWidget {
  const _AddButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        border: Border.all(
          color: LauncherTokens.b2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '＋',
            style: TextStyle(
              fontSize: 13,
              color: LauncherTokens.t3,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Add App',
            style: TextStyle(
              fontFamily: LauncherTokens.fontBody,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: LauncherTokens.t3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection status indicator.
class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: LauncherTokens.b1)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: LauncherTokens.ok,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: LauncherTokens.ok.withOpacity(0.8),
                  blurRadius: 7,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'AGL CONNECTED',
            style: TextStyle(
              fontFamily: LauncherTokens.fontMono,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: LauncherTokens.ok,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
