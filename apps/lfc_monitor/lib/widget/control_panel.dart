import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/lifecycle_collector.dart';
import '../data/lifecycle_data.dart';
import '../theme/lfc_palette.dart';

/// Right panel — control actions against the currently selected service.
/// Three rows: Start, Stop, ServiceMode toggle.
class ControlPanel extends StatefulWidget {
  const ControlPanel({
    super.key,
    required this.collector,
    required this.palette,
    required this.selectedService,
  });

  final LifecycleCollector collector;
  final LfcPalette palette;
  final String? selectedService;

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  ServiceMode _mode = ServiceMode.normal;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final hasTarget =
        widget.selectedService != null && widget.selectedService!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.panelBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: p.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Control',
                style: TextStyle(
                  color: p.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Target service hint
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: p.panelBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.label_outline, size: 14, color: p.subtext),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasTarget
                        ? 'target: ${widget.selectedService}'
                        : 'select a service on the left',
                    style: TextStyle(color: p.text, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Start / Stop
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Start',
                  icon: Icons.play_arrow,
                  color: const Color(0xFF4CAF50),
                  enabled: hasTarget,
                  onPressed: () => widget.collector
                      .startService(widget.selectedService!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Stop',
                  icon: Icons.stop,
                  color: const Color(0xFFF44336),
                  enabled: hasTarget,
                  onPressed: () =>
                      widget.collector.stopService(widget.selectedService!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ServiceMode toggle
          Text('ServiceMode', style: TextStyle(color: p.subtext, fontSize: 11)),
          const SizedBox(height: 6),
          SegmentedButton<ServiceMode>(
            segments: const [
              ButtonSegment(
                value: ServiceMode.normal,
                label: Text('NORMAL'),
                icon: Icon(Icons.directions_run),
              ),
              ButtonSegment(
                value: ServiceMode.otaMode,
                label: Text('OTA_MODE'),
                icon: Icon(Icons.system_update_alt),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: hasTarget
                ? (s) {
                    setState(() => _mode = s.first);
                    widget.collector
                        .setServiceMode(widget.selectedService!, _mode);
                  }
                : null,
          ),
          const SizedBox(height: 14),

          // Last error / status
          Obx(() {
            final err = widget.collector.lastError.value;
            if (err == null || err.isEmpty) {
              return Text(
                widget.collector.connected.value
                    ? 'connected'
                    : 'waiting for ROS…',
                style: TextStyle(color: p.subtext, fontSize: 11),
              );
            }
            return Text(
              err,
              style: const TextStyle(
                color: Color(0xFFFFB4A9),
                fontSize: 11,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : color.withValues(alpha: 0.3),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
