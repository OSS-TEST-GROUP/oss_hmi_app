import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roslibdart/roslibdart.dart';

import '../config/app_config.dart';
import '../controller/lifecycle_collector.dart';
import '../controller/settings_controller.dart';
import '../main.dart' show RosKeeperHolder, rosKeeperHolder;
import '../theme/lfc_palette.dart';
import '../widget/container_services_panel.dart';
import '../widget/events_panel.dart';
import 'settings_page.dart';

/// Single screen with two panels arranged horizontally on wide viewports:
///   ┌─────────────────────────┬─────────────┐
///   │ Containers & Services   │   Events    │
///   └─────────────────────────┴─────────────┘
/// On narrow viewports the panels stack vertically.
///
/// Each container card carries its own Start/Stop buttons, and so does
/// each service row inside it — the operator drives lifecycle actions
/// directly from the roster instead of through a separate Control panel.
/// ServiceMode lives in Settings (global NORMAL/OTA toggle).
class LfcViewPage extends StatefulWidget {
  const LfcViewPage({
    super.key,
    required this.cfg,
    this.palette = LfcPalette.light,
    this.keeperHolder,
    this.embedded = false,
  });

  final AppConfig cfg;
  final LfcPalette palette;

  /// When null, falls back to the global rosKeeperHolder so launcher-embed
  /// and main() callers both work without forcing an explicit hand-off.
  final RosKeeperHolder? keeperHolder;

  /// True when hosted inside hmi_launcher. In that mode the rosbridge
  /// connection is owned by the launcher (a global GetX-registered Ros that
  /// its LauncherRosKeeper re-registers on every heartbeat), so editing the
  /// URL here has no lasting effect — the launcher clobbers it. The Settings
  /// page therefore shows a read-only notice instead of the URL editor and
  /// points the operator at launcher Settings. Standalone (main()) keeps the
  /// full editable field.
  final bool embedded;

  @override
  State<LfcViewPage> createState() => _LfcViewPageState();
}

class _LfcViewPageState extends State<LfcViewPage> {
  late final LifecycleCollector _collector;
  late final SettingsController _settings;
  late final RosKeeperHolder _keeperHolder;

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
          // Embedded in hmi_launcher: the launcher's own Settings screen owns
          // rosbridge URL / theme / service mode, so hide lfc_monitor's gear to
          // avoid a second, conflicting settings surface. Standalone keeps it.
          if (!widget.embedded)
            TextButton.icon(
              key: const Key('btn_settings'),
              icon: Icon(Icons.settings, size: 18, color: p.subtext),
              label: Text('Settings', style: TextStyle(color: p.subtext)),
              onPressed: () => _showSettingsDialog(context, p),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildMultiSourceBanner(p),
          Expanded(
            child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;

          final containerServicesWidget = ContainerServicesPanel(
            collector: _collector,
            palette: p,
          );
          final eventsWidget = EventsPanel(collector: _collector, palette: p);
          const gap = SizedBox(width: 12, height: 12);

          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 55, child: containerServicesWidget),
                  gap,
                  Expanded(flex: 45, child: eventsWidget),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                SizedBox(height: 360, child: containerServicesWidget),
                gap,
                SizedBox(height: 280, child: eventsWidget),
              ],
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  /// Warning banner shown when dds_bridge reports duplicate publishers on the
  /// DDS domain (multiple core/adsw). Hidden when there is a single source.
  Widget _buildMultiSourceBanner(LfcPalette p) {
    return Obx(() {
      final w = _collector.multiSourceWarning.value;
      if (w == null) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: p.errorBg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: p.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                w,
                key: const Key('banner_multi_source'),
                style: TextStyle(
                    color: p.error, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    });
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
                  onApplyServiceMode: _collector.setAllServicesMode,
                  embedded: widget.embedded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
