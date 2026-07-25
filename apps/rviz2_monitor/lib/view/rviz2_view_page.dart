import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../controller/rviz2_controller.dart';
import '../data/rviz2_data.dart';

/// Single-screen view for rviz2_monitor (direct-docker variant).
///
/// Layout (wide ≥900px):
///   ┌─────────────────────────────┬─────────────────────────┐
///   │ Status card + Options form  │   docker logs view      │
///   └─────────────────────────────┴─────────────────────────┘
/// Narrow: panels stack vertically.
///
/// Exported from main.dart so the hmi_launcher embedded panel can reference
/// it without importing internal sub-paths directly.
class Rviz2ViewPage extends StatefulWidget {
  const Rviz2ViewPage({
    super.key,
    required this.cfg,
    this.embedded = false,
  });

  final AppConfig cfg;

  /// True when hosted inside hmi_launcher. Controls minor layout tweaks
  /// (e.g. no window-level title bar in standalone mode).
  final bool embedded;

  @override
  State<Rviz2ViewPage> createState() => _Rviz2ViewPageState();
}

class _Rviz2ViewPageState extends State<Rviz2ViewPage> {
  late final Rviz2Controller _ctrl;

  // Options form — local state (v1).
  final TextEditingController _rvizConfigCtrl = TextEditingController();
  final TextEditingController _domainIdCtrl =
      TextEditingController(text: '');

  // Log auto-scroll.
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    _ctrl = Get.isRegistered<Rviz2Controller>()
        ? Get.find<Rviz2Controller>()
        : Get.put(
            Rviz2Controller(cfg: widget.cfg),
            permanent: true,
          );

    // Auto-scroll log list to newest line on each update.
    _ctrl.logs.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollCtrl.hasClients) {
          _logScrollCtrl.animateTo(
            _logScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _rvizConfigCtrl.dispose();
    _domainIdCtrl.dispose();
    _logScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Row(
                children: [
                  Text('RViz2 Monitor',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final leftPanel = _buildLeftPanel(context);
          final rightPanel = _buildLogPanel(context);
          const gap = SizedBox(width: 12, height: 12);

          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 45, child: leftPanel),
                  gap,
                  Expanded(flex: 55, child: rightPanel),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                leftPanel,
                gap,
                SizedBox(height: 360, child: rightPanel),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Left panel: status + control + options ───────────────────────────────

  Widget _buildLeftPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(context),
        const SizedBox(height: 12),
        _buildOptionsCard(context),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final labelStyle = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: outline);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              children: [
                Icon(Icons.monitor_heart_outlined, size: 20),
                SizedBox(width: 8),
                Text(
                  'RViz2 Control',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // State badge + a one-line "what to do now" hint (state-driven).
            Obx(() {
              final info = _ctrl.container.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContainerStateRow(info: info),
                  const SizedBox(height: 6),
                  Text(_stateHint(info.state),
                      style: TextStyle(fontSize: 12, color: outline)),
                ],
              );
            }),
            const SizedBox(height: 16),
            // ── Control: Start / Stop ──
            Text('CONTROL', style: labelStyle),
            const SizedBox(height: 6),
            Obx(() {
              final state = _ctrl.container.value.state;
              final canStart = state == ContainerState.notInstalled ||
                  state == ContainerState.exited ||
                  state == ContainerState.created;
              final canStop = state == ContainerState.running;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: canStart ? _onStart : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: canStop ? _ctrl.stop : null,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 14),
            // ── Display: fullscreen / back to launcher ──
            Text('DISPLAY', style: labelStyle),
            const SizedBox(height: 6),
            Obx(() {
              final isRunning =
                  _ctrl.container.value.state == ContainerState.running;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Tooltip(
                    message: isRunning
                        ? 'Show rviz2 fullscreen'
                        : 'Start rviz2 first',
                    child: OutlinedButton.icon(
                      onPressed: isRunning ? _ctrl.showRviz2 : null,
                      icon: const Icon(Icons.view_in_ar, size: 18),
                      label: const Text('View rviz2'),
                    ),
                  ),
                  Tooltip(
                    message: 'Back to the launcher home',
                    child: OutlinedButton.icon(
                      onPressed: _ctrl.showHome,
                      icon: const Icon(Icons.home_outlined, size: 18),
                      label: const Text('Launcher'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh status',
                    onPressed: _ctrl.refreshStatus,
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            // Usage tip — the intended flow.
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Start  →  View rviz2  →  tap the Home button (top-right) to return.',
                    style: TextStyle(fontSize: 11, color: outline),
                  ),
                ),
              ],
            ),
            // Error banner
            Obx(() {
              final err = _ctrl.lastError.value;
              if (err == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        err,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => _ctrl.lastError.value = null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Options form (v1): local state.
  ///
  /// [_domainIdCtrl] feeds `-e ROS_DOMAIN_ID=<val>` when non-empty.
  /// [_rvizConfigCtrl] is reserved for future `-v <path>:/tmp/default.rviz`
  /// mount injection.
  Widget _buildOptionsCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, size: 20),
                SizedBox(width: 8),
                Text(
                  'Run Options (optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Both are optional — leave blank to use defaults. Applied on the next Start.',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 14),
            // .rviz config file path (future -v mount)
            TextField(
              controller: _rvizConfigCtrl,
              decoration: const InputDecoration(
                labelText: 'RViz config file (optional)',
                hintText: 'e.g. /etc/rviz2/default.rviz',
                helperText: 'Path to a .rviz layout file — blank uses the default view',
                prefixIcon: Icon(Icons.folder_open, size: 18),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),
            // ROS_DOMAIN_ID — appended as -e ROS_DOMAIN_ID=<val>
            TextField(
              controller: _domainIdCtrl,
              decoration: const InputDecoration(
                labelText: 'ROS_DOMAIN_ID (optional)',
                hintText: 'e.g. 0',
                helperText: 'ROS 2 domain — blank uses the default (0)',
                prefixIcon: Icon(Icons.lan_outlined, size: 18),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Right panel: docker logs ─────────────────────────────────────────────

  Widget _buildLogPanel(BuildContext context) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.article_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'docker logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Obx(() => Text(
                      '${_ctrl.logs.length} lines',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    )),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined, size: 20),
                  tooltip: 'Reload logs',
                  onPressed: _ctrl.tailLogs,
                ),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 20),
                  tooltip: 'Clear log',
                  onPressed: () => _ctrl.logs.clear(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (_ctrl.logs.isEmpty) {
                return Center(
                  child: Text(
                    'No log lines yet.\nPress Start or reload.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                );
              }
              return ListView.builder(
                controller: _logScrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _ctrl.logs.length,
                itemBuilder: (ctx, i) {
                  final line = _ctrl.logs[i];
                  return _LogLineRow(line: line);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Private action helpers ───────────────────────────────────────────────

  /// Collect option form values then call [Rviz2Controller.start].
  void _onStart() {
    final extraEnv = <String, String>{};
    final domainId = _domainIdCtrl.text.trim();
    if (domainId.isNotEmpty) {
      extraEnv['ROS_DOMAIN_ID'] = domainId;
    }
    _ctrl.start(extraEnv: extraEnv);
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

/// One-line "what to do now" hint shown under the state badge.
String _stateHint(ContainerState s) {
  switch (s) {
    case ContainerState.running:
      return 'Running — tap "View rviz2" to show it fullscreen.';
    case ContainerState.notInstalled:
    case ContainerState.exited:
    case ContainerState.created:
      return 'Stopped — tap "Start" to launch rviz2.';
  }
}

class _ContainerStateRow extends StatelessWidget {
  const _ContainerStateRow({required this.info});
  final ContainerInfo info;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    switch (info.state) {
      case ContainerState.running:
        badgeColor = Colors.green.shade600;
        break;
      case ContainerState.exited:
        badgeColor = Colors.grey.shade600;
        break;
      case ContainerState.created:
        badgeColor = Colors.orange.shade600;
        break;
      case ContainerState.notInstalled:
        badgeColor = Colors.blueGrey.shade400;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                info.state.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (info.state == ContainerState.exited &&
                info.exitCode != null &&
                info.exitCode != 0) ...[
              const SizedBox(width: 8),
              Text(
                'exit=${info.exitCode}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
        if (info.lastChangedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Last changed: ${_fmtTime(info.lastChangedAt!)}',
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ],
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $h:$m:$s';
  }
}

class _LogLineRow extends StatelessWidget {
  const _LogLineRow({required this.line});
  final LogLine line;

  @override
  Widget build(BuildContext context) {
    final isErr = line.level >= 40;
    final levelColor =
        isErr ? Colors.red.shade700 : Colors.blue.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level badge
          SizedBox(
            width: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: levelColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                line.levelLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: levelColor,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Timestamp
          Text(
            _fmtTs(line.ts),
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: Text(
              line.msg,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTs(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
