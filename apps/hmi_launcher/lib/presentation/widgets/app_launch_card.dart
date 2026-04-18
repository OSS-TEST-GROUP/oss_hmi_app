import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';

/// Auto-generated "launch this app?" confirmation card (F-04 in the plan).
///
/// Rendered in the main zone after the NLU router resolves a manifest.
/// The card shows the app's icon, name, category-as-subtitle, and a single
/// primary button that fires [onLaunch].
class AppLaunchCard extends StatelessWidget {
  const AppLaunchCard({
    super.key,
    required this.app,
    required this.onLaunch,
  });

  final AppManifest app;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(app.color);
    return Container(
      key: Key('app_launch_card_${app.id}'),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Text(app.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${app.category} · v${app.version}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            key: Key('app_launch_button_${app.id}'),
            onPressed: onLaunch,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('실행'),
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length != 6) return const Color(0xFF64748B);
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFF64748B);
  return Color(0xFF000000 | value);
}
