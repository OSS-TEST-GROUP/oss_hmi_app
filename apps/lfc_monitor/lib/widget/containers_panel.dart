import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/lifecycle_collector.dart';
import '../data/lifecycle_data.dart';
import '../theme/lfc_palette.dart';

/// F013 / F014: leftmost roster of containers known to lifecycle_mgr
/// (populated via NotifyContainerState arrivals from adsw_manager).
///
/// Each row exposes the current ContainerState, the optional exit code,
/// and two action buttons (Start / Stop) that publish a ctrl/Start
/// Container or ctrl/StopContainer request through the policy gate.
/// Tapping a row selects the container — the services panel filters
/// itself to that container's services via [selectedContainer].
class ContainersPanel extends StatelessWidget {
  const ContainersPanel({
    super.key,
    required this.collector,
    required this.palette,
    this.onTapContainer,
    this.selectedContainer,
  });

  final LifecycleCollector collector;
  final LfcPalette palette;
  final void Function(String? name)? onTapContainer;
  final String? selectedContainer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.panelBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            palette: palette,
            hasSelection: selectedContainer != null,
            onClearFilter: () => onTapContainer?.call(null),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              final entries = collector.containers.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'no containers yet — waiting for NotifyContainerState…',
                    style: TextStyle(color: palette.subtext),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    Divider(color: palette.panelBorder, height: 1),
                itemBuilder: (_, i) {
                  final info = entries[i].value;
                  return _ContainerRow(
                    info: info,
                    palette: palette,
                    selected: info.name == selectedContainer,
                    onTap: () => onTapContainer?.call(info.name),
                    onStart: () => collector.startContainer(info.name),
                    onStop: () => collector.stopContainer(info.name),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.hasSelection,
    required this.onClearFilter,
  });

  final LfcPalette palette;
  final bool hasSelection;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, color: palette.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          'Containers',
          style: TextStyle(
            color: palette.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (hasSelection)
          TextButton(
            onPressed: onClearFilter,
            style: TextButton.styleFrom(
              foregroundColor: palette.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('clear filter', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}

class _ContainerRow extends StatelessWidget {
  const _ContainerRow({
    required this.info,
    required this.palette,
    required this.selected,
    required this.onTap,
    required this.onStart,
    required this.onStop,
  });

  final ContainerInfo info;
  final LfcPalette palette;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final color = containerStateColor(info.state, palette);
    final isRunning = info.state == ContainerState.running;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.name,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StateBadge(
                  text: info.state.label,
                  color: color,
                  bg: color.withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                [
                  if (info.image.isNotEmpty) info.image,
                  if (info.exitCode != null) 'exit=${info.exitCode}',
                ].join('  ·  '),
                style: TextStyle(color: palette.subtext, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  _ActionButton(
                    label: 'Start',
                    icon: Icons.play_arrow,
                    enabled: !isRunning,
                    palette: palette,
                    onPressed: onStart,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Stop',
                    icon: Icons.stop,
                    enabled: isRunning,
                    palette: palette,
                    onPressed: onStop,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.text, required this.color, required this.bg});

  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final LfcPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled ? palette.accent : palette.subtext,
          side: BorderSide(
            color: enabled ? palette.accent.withValues(alpha: 0.4) : palette.panelBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
