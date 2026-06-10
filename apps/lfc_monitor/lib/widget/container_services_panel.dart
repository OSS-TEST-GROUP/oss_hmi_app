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
/// Both the Container header and each Service row carry their own
/// Start / Stop buttons — Container's publish ctrl/Start|StopContainer,
/// Service's publish ctrl/Start|StopService.  No separate Control panel.
class ContainerServicesPanel extends StatelessWidget {
  const ContainerServicesPanel({
    super.key,
    required this.collector,
    required this.palette,
  });

  final LifecycleCollector collector;
  final LfcPalette palette;

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
              // Services with an empty container_name (e.g. AGL apps reported
              // by agl_adsw_manager via DiagReport, which does not emit a
              // NotifyContainerState) are collected separately so they still
              // surface — see _OrphanServicesCard below.
              final byContainer = <String, List<ServiceInfo>>{};
              final orphans = <ServiceInfo>[];
              for (final svc in collector.services.values) {
                if (svc.containerName.isEmpty) {
                  orphans.add(svc);
                } else {
                  byContainer
                      .putIfAbsent(svc.containerName, () => <ServiceInfo>[])
                      .add(svc);
                }
              }
              for (final list in byContainer.values) {
                list.sort((a, b) => a.name.compareTo(b.name));
              }
              orphans.sort((a, b) => a.name.compareTo(b.name));

              if (containers.isEmpty && orphans.isEmpty) {
                return Center(
                  child: Text(
                    'no containers/services yet — waiting for '
                    'NotifyContainerState / LifecycleDiagReport…',
                    style: TextStyle(color: palette.subtext),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final cards = <Widget>[
                for (final c in containers)
                  _ContainerCard(
                    info: c,
                    services: byContainer[c.name] ?? const <ServiceInfo>[],
                    palette: palette,
                    onStart: () => collector.startContainer(c.name),
                    onStop: () => collector.stopContainer(c.name),
                    onStartService: collector.startService,
                    onStopService: collector.stopService,
                    onChangeServiceRecovery: collector.setServiceRecoveryPolicy,
                  ),
                if (orphans.isNotEmpty)
                  _OrphanServicesCard(
                    services: orphans,
                    palette: palette,
                    onStartService: collector.startService,
                    onStopService: collector.stopService,
                    onChangeServiceRecovery: collector.setServiceRecoveryPolicy,
                  ),
              ];

              return ListView.separated(
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => cards[i],
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
    required this.onStart,
    required this.onStop,
    required this.onStartService,
    required this.onStopService,
    required this.onChangeServiceRecovery,
  });

  final ContainerInfo info;
  final List<ServiceInfo> services;
  final LfcPalette palette;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final void Function(String serviceName) onStartService;
  final void Function(String serviceName) onStopService;
  final void Function(String serviceName, RecoveryPolicy policy)
      onChangeServiceRecovery;

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
              // exit indicator inline next to the name, before the state
              // badge. -1 is the "unknown / not-yet-started" sentinel used
              // when adsw_manager can't recover the real exit code (the
              // container init `tail -f /dev/null` doesn't wait() children
              // so the OS discards the exit status). Hide -1 entirely so
              // the column means "exit code we actually observed".
              if (_visibleExit(info.exitCode) != null) ...[
                _ExitChip(value: info.exitCode!, palette: p),
                const SizedBox(width: 6),
              ],
              _StateBadge(
                text: info.state.label,
                color: color,
                bg: color.withValues(alpha: 0.12),
              ),
            ],
          ),
          if (info.image.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                info.image,
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
                    onStart: () => onStartService(services[i].name),
                    onStop: () => onStopService(services[i].name),
                    onChangeRecovery: (policy) =>
                        onChangeServiceRecovery(services[i].name, policy),
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

/// Card listing services that are NOT backed by a NotifyContainerState
/// container — i.e. services lifecycle_mgr knows about (via DiagReport) but
/// that no container card would otherwise surface. This is how AGL apps
/// registered by agl_adsw_manager (which publishes NotifyServiceState /
/// UpdateServiceList, not NotifyContainerState) become visible in the panel.
class _OrphanServicesCard extends StatelessWidget {
  const _OrphanServicesCard({
    required this.services,
    required this.palette,
    required this.onStartService,
    required this.onStopService,
    required this.onChangeServiceRecovery,
  });

  final List<ServiceInfo> services;
  final LfcPalette palette;
  final void Function(String serviceName) onStartService;
  final void Function(String serviceName) onStopService;
  final void Function(String serviceName, RecoveryPolicy policy)
      onChangeServiceRecovery;

  @override
  Widget build(BuildContext context) {
    final p = palette;
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
              Icon(Icons.widgets_outlined, color: p.subtext, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Services (no container)',
                  style: TextStyle(color: p.text, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StateBadge(
                text: '${services.length}',
                color: p.subtext,
                bg: p.subtext.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: p.panelBorder, height: 1),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < services.length; i++) ...[
                _ServiceRow(
                  info: services[i],
                  palette: p,
                  onStart: () => onStartService(services[i].name),
                  onStop: () => onStopService(services[i].name),
                  onChangeRecovery: (policy) =>
                      onChangeServiceRecovery(services[i].name, policy),
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
    required this.onStart,
    required this.onStop,
    required this.onChangeRecovery,
  });

  final ServiceInfo info;
  final LfcPalette palette;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final void Function(RecoveryPolicy policy) onChangeRecovery;

  @override
  Widget build(BuildContext context) {
    final color = stateColor(info.state, palette);
    final currentPolicy = info.recoveryPolicy.isEmpty
        ? RecoveryPolicy.defaultPolicy
        : RecoveryPolicy.fromLabel(info.recoveryPolicy);
    // Mirror the container card's Start/Stop gating: Start is offered
    // while the process is gone (NOT_RUNNING / RUNNING_NO_RESPONSE),
    // Stop while it's alive (INITIALIZING / RUNNING).  TERMINATING and
    // UNKNOWN leave both disabled so the operator can't queue duplicate
    // actuations during a state transition.
    final isAlive = info.state == ServiceState.initializing ||
        info.state == ServiceState.running;
    final isDown = info.state == ServiceState.notRunning ||
        info.state == ServiceState.runningNoResponse;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: dot + name + exit chip + state badge — same shape as
          // _ContainerCard so the operator scans the state column down the
          // panel uniformly. exit chip sits inline before the badge and is
          // hidden for -1 (unknown sentinel).
          Row(
            children: [
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.name,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_visibleExit(info.exitCode) != null) ...[
                _ExitChip(value: info.exitCode!, palette: palette),
                const SizedBox(width: 6),
              ],
              _StateBadge(
                text: info.state.label,
                color: color,
                bg: color.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Start / Stop on the left, recovery dropdown pushed to the
          // far right via a Spacer — visually pairs the dropdown column with
          // the state badge column above it, keeping the action buttons
          // grouped on the left.
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              children: [
                _ActionButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  enabled: isDown,
                  palette: palette,
                  onPressed: onStart,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Stop',
                  icon: Icons.stop,
                  enabled: isAlive,
                  palette: palette,
                  onPressed: onStop,
                ),
                const Spacer(),
                _RecoveryDropdown(
                  current: currentPolicy,
                  palette: palette,
                  onChanged: onChangeRecovery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryDropdown extends StatelessWidget {
  const _RecoveryDropdown({
    required this.current,
    required this.palette,
    required this.onChanged,
  });

  final RecoveryPolicy current;
  final LfcPalette palette;
  final void Function(RecoveryPolicy policy) onChanged;

  @override
  Widget build(BuildContext context) {
    // Show only the operator-relevant policies (MANUAL / ALWAYS / ON_FAILURE).
    // If the service's current policy comes in as one of the hidden values
    // (DEFAULT / ON_SUCCESS / ON_NOT_RESPONDING) we still need to include it
    // in the items list — DropdownButton asserts that `value` is one of the
    // declared items. We keep it as a read-only choice so the operator sees
    // the actual configured policy without being able to re-select it.
    final visible = <RecoveryPolicy>[
      ...RecoveryPolicy.userSelectable,
      if (!RecoveryPolicy.userSelectable.contains(current)) current,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: palette.panelBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RecoveryPolicy>(
          value: current,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: palette.subtext, size: 16),
          style: TextStyle(color: palette.text, fontSize: 10.5),
          dropdownColor: palette.panel,
          items: visible
              .map((p) => DropdownMenuItem<RecoveryPolicy>(
                    value: p,
                    child: Text(p.label, style: TextStyle(fontSize: 10.5, color: palette.text)),
                  ))
              .toList(),
          onChanged: (next) {
            if (next == null || next == current) return;
            onChanged(next);
          },
        ),
      ),
    );
  }
}

// Hide exit codes that carry no operator-actionable signal:
//   * -1  is the "unknown / not yet started" sentinel adsw_manager stamps
//         when it can't recover a real exit code (container init
//         `tail -f /dev/null` doesn't wait() its children, so the OS
//         discards the status before we can ask).
//   *  0  on a container card is a cascade — ContainerHealthMonitor::PollLoop
//         hard-codes exit_code=0 while is_running==true, so a healthy
//         container always reports 0. Same story propagates to its services
//         via OnContainerStateChanged. The 0 here is "no incident", not a
//         confirmed clean exit, so suppressing it leaves the chip column
//         meaning "non-zero exit actually observed".
// Net effect: the chip only shows when a non-zero exit code has been
// reported, matching the operator's mental model of "show me failures".
int? _visibleExit(int? raw) {
  if (raw == null) return null;
  if (raw == -1 || raw == 0) return null;
  return raw;
}

class _ExitChip extends StatelessWidget {
  const _ExitChip({required this.value, required this.palette});

  final int value;
  final LfcPalette palette;

  @override
  Widget build(BuildContext context) {
    // Only non-zero exit codes reach here (see _visibleExit). Render in
    // accent so the failure stands out from the surrounding text.
    final fg = palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: fg.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'exit=$value',
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w500),
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
