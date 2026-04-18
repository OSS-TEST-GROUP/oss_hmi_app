import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';

/// Dynamic vertical app list (Zone 2 in the 4-Zone layout).
///
/// Rebuilds from the PluginRegistry's `apps` list; items are sorted by
/// `category` then `name` so the sidebar order is stable across launches.
/// Tapping an item invokes [onAppSelected] with the target manifest.
class SidebarNavigator extends StatelessWidget {
  const SidebarNavigator({
    super.key,
    required this.apps,
    required this.onAppSelected,
    this.selectedAppId,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = List<AppManifest>.of(apps)
      ..sort((a, b) {
        final byCategory = a.category.compareTo(b.category);
        if (byCategory != 0) return byCategory;
        return a.name.compareTo(b.name);
      });
    return ListView(
      key: const Key('sidebar_list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final app in sorted)
          _SidebarItem(
            app: app,
            selected: app.id == selectedAppId,
            onTap: () => onAppSelected(app),
          ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  final AppManifest app;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(app.color);
    return InkWell(
      key: Key('sidebar_item_${app.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E293B) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(app.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                app.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFCBD5E1),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parse `#RRGGBB` into a Flutter [Color]. Returns a neutral slate gray
/// when the input is malformed so the UI never crashes on a bad manifest.
Color _parseColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length != 6) return const Color(0xFF64748B);
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFF64748B);
  return Color(0xFF000000 | value);
}
