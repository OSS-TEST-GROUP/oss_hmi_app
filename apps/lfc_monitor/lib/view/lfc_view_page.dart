import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import '../config/app_config.dart';
import '../controller/lifecycle_collector.dart';
import '../controller/settings_controller.dart';
import '../main.dart' show RosKeeperHolder, rosKeeperHolder;
import '../theme/lfc_palette.dart';
import '../widget/containers_panel.dart';
import '../widget/control_panel.dart';
import '../widget/events_panel.dart';
import '../widget/services_panel.dart';
import 'settings_page.dart';

/// Single screen with four panels arranged horizontally on wide viewports:
///   ┌────────────┬──────────┬───────────┬──────────┐
///   │ Containers │ Services │  Events   │ Control  │
///   └────────────┴──────────┴───────────┴──────────┘
/// On narrow viewports the panels stack vertically.
///
/// F014: Containers is the new first column; selecting one filters the
/// Services panel. Service selection drives the Control panel.  Header
/// gained a Settings button that opens a dialog for live URL / theme
/// edits via SettingsController + RosKeeperHolder.
class LfcViewPage extends StatefulWidget {
  const LfcViewPage({
    super.key,
    required this.cfg,
    this.palette = LfcPalette.dark,
    this.keeperHolder,
  });

  final AppConfig cfg;
  final LfcPalette palette;

  /// When null, falls back to the global rosKeeperHolder so launcher-embed
  /// and main() callers both work without forcing an explicit hand-off.
  final RosKeeperHolder? keeperHolder;

  @override
  State<LfcViewPage> createState() => _LfcViewPageState();
}

class _LfcViewPageState extends State<LfcViewPage> {
  late final LifecycleCollector _collector;
  late final SettingsController _settings;
  late final RosKeeperHolder _keeperHolder;

  String? _selectedService;
  String? _selectedContainer;

  @override
  void initState() {
    super.initState();
    _keeperHolder = widget.keeperHolder ?? rosKeeperHolder;
    _settings = SettingsController(
      initialConfig: widget.cfg,
      readKeeper: () => _keeperHolder.current,
      writeKeeper: _keeperHolder.replace,
    );

    // GetX collector — keep singleton across rebuilds. Tests reuse the same
    // controller via Get.find().
    _collector = Get.isRegistered<LifecycleCollector>()
        ? Get.find<LifecycleCollector>()
        : Get.put(
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
        iconTheme: IconThemeData(color: p.text),
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
                  _collector.connected.value
                      ? '● connected'
                      : '○ disconnected',
                  style: TextStyle(
                    color: _collector.connected.value
                        ? p.success
                        : p.subtext,
                    fontSize: 12,
                  ),
                )),
            const SizedBox(width: 12),
            // Mirror live RosKeeper URL so it tracks Settings edits.
            AnimatedBuilder(
              animation: _keeperHolder,
              builder: (_, __) => Text(
                _keeperHolder.current.cfg.rosUrl.toString(),
                style: TextStyle(color: p.subtext, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            key: const Key('btn_settings'),
            icon: Icon(Icons.settings, size: 18, color: p.subtext),
            label: Text('Settings', style: TextStyle(color: p.subtext)),
            onPressed: () => _showSettingsDialog(context, p),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 1280;

          // Panel widgets — kept naked here so wide layout can drop each
          // into an Expanded (which subtracts gaps + outer padding from
          // the available width itself) and narrow layout can stack them
          // in a ListView.  An earlier attempt fixed each panel to
          // `c.maxWidth * frac` and added gaps on top — that overflowed by
          // exactly (gaps + outer padding) since the fractions already
          // summed to 1.00.
          final containersWidget = ContainersPanel(
            collector: _collector,
            palette: p,
            selectedContainer: _selectedContainer,
            onTapContainer: (name) => setState(() {
              _selectedContainer =
                  (name == null || name == _selectedContainer) ? null : name;
            }),
          );
          final servicesWidget = ServicesPanel(
            collector: _collector,
            palette: p,
            selectedService: _selectedService,
            filterContainer: _selectedContainer,
            onTapService: (name) => setState(() => _selectedService = name),
          );
          final eventsWidget = EventsPanel(collector: _collector, palette: p);
          final controlWidget = ControlPanel(
            collector: _collector,
            palette: p,
            selectedService: _selectedService,
          );
          const gap = SizedBox(width: 12, height: 12);

          if (wide) {
            // flex weights mirror the original .26/.24/.28/.22 ratio.
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 26, child: containersWidget),
                  gap,
                  Expanded(flex: 24, child: servicesWidget),
                  gap,
                  Expanded(flex: 28, child: eventsWidget),
                  gap,
                  Expanded(flex: 22, child: controlWidget),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                SizedBox(height: 240, child: containersWidget),
                gap,
                SizedBox(height: 240, child: servicesWidget),
                gap,
                SizedBox(height: 240, child: eventsWidget),
                gap,
                controlWidget,
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, LfcPalette p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: p.accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: p.subtext),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(color: p.panelBorder, height: 1),
              Flexible(
                child: SettingsPage(
                  controller: _settings,
                  currentUrlProvider: () =>
                      _keeperHolder.current.cfg.rosUrl.toString(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
