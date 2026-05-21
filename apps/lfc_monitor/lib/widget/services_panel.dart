import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/lifecycle_collector.dart';
import '../data/lifecycle_data.dart';
import '../theme/lfc_palette.dart';

/// Left panel — running roster of registered services with current state,
/// recovery policy, and last exit code. Updates whenever the collector
/// receives NotifyServiceState / GetServiceStateResponse / LifecycleDiagReport.
class ServicesPanel extends StatelessWidget {
  const ServicesPanel({
    super.key,
    required this.collector,
    required this.palette,
    this.onTapService,
    this.selectedService,
  });

  final LifecycleCollector collector;
  final LfcPalette palette;
  final void Function(String name)? onTapService;
  final String? selectedService;

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
          _Header(palette: palette),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              final entries = collector.services.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'no services yet — waiting for UpdateServiceListRequest…',
                    style: TextStyle(color: palette.subtext),
                  ),
                );
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) =>
                    Divider(color: palette.panelBorder, height: 1),
                itemBuilder: (_, i) {
                  final info = entries[i].value;
                  final isSelected = info.name == selectedService;
                  return _ServiceRow(
                    info: info,
                    palette: palette,
                    selected: isSelected,
                    onTap: () => onTapService?.call(info.name),
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
  const _Header({required this.palette});
  final LfcPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.dns_outlined, color: palette.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          'Services',
          style: TextStyle(
            color: palette.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.info,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final ServiceInfo info;
  final LfcPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = stateColor(info.state, palette);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      info.state.label,
                      if (info.recoveryPolicy.isNotEmpty)
                        'recovery=${info.recoveryPolicy}',
                      if (info.exitCode != null) 'exit=${info.exitCode}',
                    ].join('  ·  '),
                    style: TextStyle(color: palette.subtext, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
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
