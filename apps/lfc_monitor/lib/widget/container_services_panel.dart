import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/lifecycle_collector.dart';
import '../data/lifecycle_data.dart';
import '../theme/lfc_palette.dart';

/// F014 follow-up: unified roster.  Container cards each list their own
/// services (grouped by ServiceInfo.containerName).  Services whose
/// container_name is empty — i.e. anything that didn't come through
/// adsw_manager's UpdateServiceListRequest — are hidden entirely, since
/// the operator's mental model here is "what is adsw_manager managing".
///
/// Selecting a service row drives the Control panel; the Container
/// header has its own Start / Stop buttons that publish ctrl/Start
/// Container / ctrl/StopContainer.
class ContainerServicesPanel extends StatelessWidget {
  const ContainerServicesPanel({
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
              final containers = collector.containers.values.toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              // Bucket services by container_name once per build.
              final byContainer = <String, List<ServiceInfo>>{};
              for (final svc in collector.services.values) {
                if (svc.containerName.isEmpty) continue;
                byContainer
                    .putIfAbsent(svc.containerName, () => <ServiceInfo>[])
                    .add(svc);
              }
              for (final list in byContainer.values) {
                list.sort((a, b) => a.name.compareTo(b.name));
              }

              if (containers.isEmpty) {
                return Center(
                  child: Text(
                    'no containers yet — waiting for NotifyContainerState…',
                    style: TextStyle(color: palette.subtext),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: containers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final c = containers[i];
                  return _ContainerCard(
                    info: c,
                    services: byContainer[c.name] ?? const <ServiceInfo>[],
                    palette: palette,
                    selectedService: selectedService,
                    onTapService: onTapService,
                    onStart: () => collector.startContainer(c.name),
                    onStop: () => collector.stopContainer(c.name),
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
        Icon(Icons.inventory_2_outlined, color: palette.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          'Containers & Services',
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

class _ContainerCard extends StatelessWidget {
  const _ContainerCard({
    required this.info,
    required this.services,
    required this.palette,
    required this.selectedService,
    required this.onTapService,
    required this.onStart,
    required this.onStop,
  });

  final ContainerInfo info;
  final List<ServiceInfo> services;
  final LfcPalette palette;
  final String? selectedService;
  final void Function(String name)? onTapService;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final color = containerStateColor(info.state, p);
    final isRunning = info.state == ContainerState.running;
    return Container(
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.panelBorder),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.name,
                  style: TextStyle(
                    color: p.text,
                    fontWeight: FontWeight.w600,
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
          if (info.image.isNotEmpty || info.exitCode != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                [
                  if (info.image.isNotEmpty) info.image,
                  if (info.exitCode != null) 'exit=${info.exitCode}',
                ].join('  ·  '),
                style: TextStyle(color: p.subtext, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                _ActionButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  enabled: !isRunning,
                  palette: p,
                  onPressed: onStart,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Stop',
                  icon: Icons.stop,
                  enabled: isRunning,
                  palette: p,
                  onPressed: onStop,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: p.panelBorder, height: 1),
          if (services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                'no services registered under this container yet',
                style: TextStyle(color: p.subtext, fontSize: 11),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < services.length; i++) ...[
                  _ServiceRow(
                    info: services[i],
                    palette: p,
                    selected: services[i].name == selectedService,
                    onTap: () => onTapService?.call(services[i].name),
                  ),
                  if (i != services.length - 1)
                    Divider(color: p.panelBorder, height: 1),
                ],
              ],
            ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? palette.accent.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                      fontSize: 13,
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
                    style: TextStyle(color: palette.subtext, fontSize: 10.5),
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
            color: enabled
                ? palette.accent.withValues(alpha: 0.4)
                : palette.panelBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
