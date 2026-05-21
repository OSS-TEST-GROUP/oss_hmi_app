import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/lifecycle_collector.dart';
import '../data/lifecycle_data.dart';
import '../theme/lfc_palette.dart';

/// Middle panel — newest-first lifecycle event timeline. Combines state
/// transitions (NotifyServiceState) and control-command acks (Start /
/// Stop / SetServiceMode responses).
class EventsPanel extends StatelessWidget {
  const EventsPanel({
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
          Row(
            children: [
              Icon(Icons.timeline, color: palette.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Events',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (collector.events.isEmpty) {
                return Center(
                  child: Text(
                    'no events yet',
                    style: TextStyle(color: palette.subtext),
                  ),
                );
              }
              return ListView.separated(
                itemCount: collector.events.length,
                separatorBuilder: (_, __) =>
                    Divider(color: palette.panelBorder, height: 1),
                itemBuilder: (_, i) => _EventRow(
                  event: collector.events[i],
                  palette: palette,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.palette});
  final LifecycleEvent event;
  final LfcPalette palette;

  @override
  Widget build(BuildContext context) {
    final hh = event.timestamp.hour.toString().padLeft(2, '0');
    final mm = event.timestamp.minute.toString().padLeft(2, '0');
    final ss = event.timestamp.second.toString().padLeft(2, '0');
    final ms = event.timestamp.millisecond.toString().padLeft(3, '0');

    final String text;
    final Color dotColor;
    switch (event.kind) {
      case LifecycleEventKind.stateChange:
        text = '${event.serviceName}: ${event.from.label} → ${event.to.label}';
        dotColor = stateColor(event.to, palette);
        break;
      case LifecycleEventKind.startResponse:
      case LifecycleEventKind.stopResponse:
      case LifecycleEventKind.setModeResponse:
      case LifecycleEventKind.updateList:
        text = '${event.kind.name}  ${event.detail ?? ''}';
        dotColor = palette.accent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$hh:$mm:$ss.$ms',
            style: TextStyle(
              color: palette.subtext,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.text, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
