import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../../domain/app_visibility_store.dart';

/// Full-screen (or dialog) panel that lists every discovered app and lets
/// the user enable / disable each one via a toggle switch.
///
/// [allApps] must include **all** entries from [PluginRegistry.entries] that
/// parsed successfully (compatible + incompatible) — that is, the complete
/// catalogue regardless of current visibility state.
///
/// Toggling a switch calls [store.toggle] which persists immediately and
/// notifies listeners; the sidebar / home rebuild via [ListenableBuilder].
///
/// Widget keys for test automation:
///   - `manage_apps_panel`         — root container of this panel
///   - `manage_toggle_<id>`        — the [Switch] for app [id]
class ManageAppsPanel extends StatelessWidget {
  const ManageAppsPanel({
    super.key,
    required this.allApps,
    required this.store,
    required this.onClose,
  });

  /// Every app that was parsed from manifests (enabled or disabled).
  final List<AppManifest> allApps;

  /// Visibility store — read and mutated in response to user toggles.
  final AppVisibilityStore store;

  /// Called when the user taps the close / back button.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('manage_apps_panel'),
      color: const Color(0xFFF4F6F8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onClose: onClose),
          Expanded(
            child: allApps.isEmpty
                ? const _EmptyState()
                : _AppList(apps: allApps, store: store),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFDDE3EA))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF15191F),
            onPressed: onClose,
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          const Icon(Icons.apps, size: 22, color: Color(0xFF15191F)),
          const SizedBox(width: 10),
          const Text(
            'Manage Apps',
            style: TextStyle(
              color: Color(0xFF15191F),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const Flexible(
            child: Text(
              'Toggle to show or hide apps in the sidebar',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF65707C), fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ── App list ──────────────────────────────────────────────────────────────

class _AppList extends StatelessWidget {
  const _AppList({required this.apps, required this.store});

  final List<AppManifest> apps;
  final AppVisibilityStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          itemCount: apps.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFDDE3EA)),
          itemBuilder: (_, i) => _AppRow(app: apps[i], store: store),
        );
      },
    );
  }
}

// ── Individual app row ────────────────────────────────────────────────────

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.store});

  final AppManifest app;
  final AppVisibilityStore store;

  @override
  Widget build(BuildContext context) {
    final enabled = store.isEnabled(app.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // App icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _parseHex(app.color).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                app.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFF15191F)
                        : const Color(0xFF65707C),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${app.category} · v${app.version}',
                  style: const TextStyle(
                    color: Color(0xFF65707C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Toggle switch
          Switch(
            key: Key('manage_toggle_${app.id}'),
            value: enabled,
            onChanged: (_) => store.toggle(app.id),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) {
    final s = hex.replaceAll('#', '');
    if (s.length != 6) return const Color(0xFF2E6BE6);
    final v = int.tryParse(s, radix: 16);
    if (v == null) return const Color(0xFF2E6BE6);
    return Color(0xFF000000 | v);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apps_outlined, size: 36, color: Color(0xFF65707C)),
          SizedBox(height: 12),
          Text(
            'No apps discovered',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF15191F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add a manifest.json to the apps/ directory.',
            style: TextStyle(fontSize: 12, color: Color(0xFF65707C)),
          ),
        ],
      ),
    );
  }
}
