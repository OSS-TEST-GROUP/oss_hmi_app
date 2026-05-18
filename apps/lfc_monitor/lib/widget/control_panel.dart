import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/lifecycle_collector.dart';
import '../theme/lfc_palette.dart';

/// Right panel — control actions against the currently selected service.
/// Two rows: Start, Stop.  ServiceMode lives in the Settings dialog now
/// (global NORMAL/OTA toggle applies to every registered service in one
/// ctrl/SetServiceMode publish).
class ControlPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = palette;
    final hasTarget = selectedService != null && selectedService!.isNotEmpty;

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
                        ? 'target: $selectedService'
                        : 'select a service on the left',
                    style: TextStyle(color: p.text, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
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
                  color: p.success,
                  enabled: hasTarget,
                  onPressed: () => collector.startService(selectedService!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Stop',
                  icon: Icons.stop,
                  color: p.error,
                  enabled: hasTarget,
                  onPressed: () => collector.stopService(selectedService!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Last error / status
          Obx(() {
            final err = collector.lastError.value;
            if (err == null || err.isEmpty) {
              return Text(
                collector.connected.value ? 'connected' : 'waiting for ROS…',
                style: TextStyle(color: p.subtext, fontSize: 11),
              );
            }
            return Text(
              err,
              style: TextStyle(color: p.error, fontSize: 11),
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
