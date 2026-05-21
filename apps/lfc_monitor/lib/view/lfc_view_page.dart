import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import '../config/app_config.dart';
import '../controller/lifecycle_collector.dart';
import '../theme/lfc_palette.dart';
import '../widget/control_panel.dart';
import '../widget/events_panel.dart';
import '../widget/services_panel.dart';

/// Single screen with three panels arranged horizontally:
///   ┌──────────┬───────────┬──────────┐
///   │ Services │  Events   │ Control  │
///   └──────────┴───────────┴──────────┘
/// On narrow viewports the three panels stack vertically.
class LfcViewPage extends StatefulWidget {
  const LfcViewPage({
    super.key,
    required this.cfg,
    this.palette = LfcPalette.defaults,
  });

  final AppConfig cfg;
  final LfcPalette palette;

  @override
  State<LfcViewPage> createState() => _LfcViewPageState();
}

class _LfcViewPageState extends State<LfcViewPage> {
  late final LifecycleCollector _collector;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _collector = Get.put(
      LifecycleCollector(
        cfg: widget.cfg,
        topicFactory: (r, n, t) => Topic(ros: r, name: n, type: t),
      ),
      permanent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.memory_outlined, color: p.accent, size: 22),
            const SizedBox(width: 8),
            Text(
              'lfc_monitor',
              style: TextStyle(
                color: p.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Obx(() => Text(
                  _collector.connected.value ? '● connected' : '○ disconnected',
                  style: TextStyle(
                    color: _collector.connected.value
                        ? const Color(0xFF4CAF50)
                        : p.subtext,
                    fontSize: 12,
                  ),
                )),
            const SizedBox(width: 12),
            Text(
              widget.cfg.rosUrl.toString(),
              style: TextStyle(color: p.subtext, fontSize: 11),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1100;
          final services = SizedBox(
            width: wide ? c.maxWidth * 0.32 : double.infinity,
            child: ServicesPanel(
              collector: _collector,
              palette: p,
              selectedService: _selected,
              onTapService: (name) => setState(() => _selected = name),
            ),
          );
          final events = SizedBox(
            width: wide ? c.maxWidth * 0.38 : double.infinity,
            child: EventsPanel(
              collector: _collector,
              palette: p,
            ),
          );
          final control = SizedBox(
            width: wide ? c.maxWidth * 0.28 : double.infinity,
            child: ControlPanel(
              collector: _collector,
              palette: p,
              selectedService: _selected,
            ),
          );
          const gap = SizedBox(width: 12, height: 12);

          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [services, gap, events, gap, control],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(height: 280, child: services),
                gap,
                SizedBox(height: 280, child: events),
                gap,
                control,
              ],
            ),
          );
        },
      ),
    );
  }
}
