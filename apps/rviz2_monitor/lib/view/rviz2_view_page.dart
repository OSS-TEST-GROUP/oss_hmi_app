import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import '../config/app_config.dart';
import '../controller/rviz2_controller.dart';
import '../data/rviz2_data.dart';
import '../main.dart' show RosKeeperHolder, rosKeeperHolder;

/// Single-screen view for rviz2_monitor.
///
/// Layout (wide ≥900px):
///   ┌─────────────────────────────┬─────────────────────────┐
///   │ Status card + Options form  │   /rosout Log view      │
///   └─────────────────────────────┴─────────────────────────┘
/// Narrow: panels stack vertically.
///
/// Exported from main.dart so the hmi_launcher embedded panel can reference
/// it without importing internal sub-paths directly.
class Rviz2ViewPage extends StatefulWidget {
  const Rviz2ViewPage({
    super.key,
    required this.cfg,
    this.keeperHolder,
    this.embedded = false,
  });

  final AppConfig cfg;

  /// When null, falls back to the global rosKeeperHolder so launcher-embed
  /// and standalone main() both work without an explicit hand-off.
  final RosKeeperHolder? keeperHolder;

  /// True when hosted inside hmi_launcher. Controls minor layout tweaks
  /// (e.g. no window-level title bar in standalone mode).
  final bool embedded;

  @override
  State<Rviz2ViewPage> createState() => _Rviz2ViewPageState();
}

class _Rviz2ViewPageState extends State<Rviz2ViewPage> {
  late final Rviz2Controller _ctrl;
  late final RosKeeperHolder _keeperHolder;

  // Options form — local state only in v1 (persisted to prefs in follow-up).
  final TextEditingController _rvizConfigCtrl = TextEditingController();
  final TextEditingController _domainIdCtrl = TextEditingController(text: '0');
  String _gpuMode = 'SW';

  // Log auto-scroll.
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _keeperHolder = widget.keeperHolder ?? rosKeeperHolder;

    _ctrl = Get.isRegistered<Rviz2Controller>()
        ? Get.find<Rviz2Controller>()
        : Get.put(
            Rviz2Controller(
              cfg: widget.cfg,
              topicFactory: (r, n, t) => Topic(ros: r, name: n, type: t),
            ),
            permanent: true,
          );

    // Auto-scroll log list when new lines arrive.
    _ctrl.logs.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollCtrl.hasClients) {
          _logScrollCtrl.animateTo(
            0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Row(
                children: [
                  Text('🤖', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
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

  // ─── Left panel: status + control + options ──────────────────────────────

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
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + connection indicator
            Row(
              children: [
                const Icon(Icons.monitor_heart_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'rviz2 Container',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Obx(() => _ConnectionBadge(connected: _ctrl.connected.value)),
                const SizedBox(width: 8),
                // Live rosbridge URL
                AnimatedBuilder(
                  animation: _keeperHolder,
                  builder: (_, __) => Text(
                    _keeperHolder.current.cfg.rosUrl.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // State badge + exit code + lastChanged
            Obx(() {
              final info = _ctrl.container.value;
              return _ContainerStateRow(info: info);
            }),
            const SizedBox(height: 16),
            // Start / Stop buttons
            Obx(() {
              final state = _ctrl.container.value.state;
              final isRunning = state == ContainerState.running;
              final isStopped = state == ContainerState.stopped ||
                  state == ContainerState.unknownState;
              return Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: isStopped ? _ctrl.startRviz2 : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: isRunning ? _ctrl.stopRviz2 : null,
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
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Options form (v1): local state only. Values will feed future start args
  /// passed via adsw_manager extra_args or ROS param topics (see design doc §3).
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
                  'Run Options (v1 — local state)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Options are saved locally; will feed future container start args.',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 14),
            // .rviz config file path
            TextField(
              controller: _rvizConfigCtrl,
              decoration: const InputDecoration(
                labelText: '.rviz config path',
                hintText: '/etc/rviz2/default.rviz',
                prefixIcon: Icon(Icons.folder_open, size: 18),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            // ROS_DOMAIN_ID
            TextField(
              controller: _domainIdCtrl,
              decoration: const InputDecoration(
                labelText: 'ROS_DOMAIN_ID',
                hintText: '0',
                prefixIcon: Icon(Icons.lan_outlined, size: 18),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            // GPU mode toggle
            Row(
              children: [
                const Icon(Icons.videogame_asset_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('GPU Mode:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 12),
                StatefulBuilder(
                  builder: (_, setS) => SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'SW', label: Text('SW (llvmpipe)')),
                      ButtonSegment(value: 'HW', label: Text('HW (NVIDIA)')),
                    ],
                    selected: {_gpuMode},
                    onSelectionChanged: (sel) =>
                        setS(() => _gpuMode = sel.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Note: GPU mode change takes effect on next Start.',
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Right panel: /rosout log view ──────────────────────────────────────

  Widget _buildLogPanel(BuildContext context) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Log header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.article_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '/rosout Log',
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
                  icon: const Icon(Icons.clear_all, size: 20),
                  tooltip: 'Clear log',
                  onPressed: () => _ctrl.logs.clear(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Log list
          Expanded(
            child: Obx(() {
              if (_ctrl.logs.isEmpty) {
                return Center(
                  child: Text(
                    'No /rosout messages yet.\nMessages filtered to node name containing "${widget.cfg.containerName}".',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                );
              }
              return ListView.builder(
                controller: _logScrollCtrl,
                reverse: false,
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
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: connected
            ? Colors.green.shade100
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: connected ? Colors.green.shade400 : Colors.grey.shade400,
        ),
      ),
      child: Text(
        connected ? '● connected' : '○ disconnected',
        style: TextStyle(
          fontSize: 11,
          color: connected ? Colors.green.shade800 : Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
      case ContainerState.stopped:
        badgeColor = Colors.grey.shade600;
        break;
      case ContainerState.paused:
        badgeColor = Colors.orange.shade600;
        break;
      case ContainerState.unknownState:
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
            if (info.exitCode != null && info.exitCode != 0) ...[
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
    final Color levelColor;
    switch (line.levelLabel) {
      case 'FATAL':
      case 'ERROR':
        levelColor = Colors.red.shade700;
        break;
      case 'WARN':
        levelColor = Colors.orange.shade700;
        break;
      case 'DEBUG':
        levelColor = Colors.blueGrey.shade400;
        break;
      default: // INFO
        levelColor = Colors.blue.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level badge
          SizedBox(
            width: 44,
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
