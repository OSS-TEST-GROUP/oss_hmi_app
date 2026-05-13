import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../../domain/plugin_registry.dart';
import '../../launcher_bot/services/launcher_bot_ai_service.dart';
import '../../launcher_bot/services/launcher_bot_controller.dart';
import '../launcher_bot/launcher_bot_panel.dart';
import '../panels/adsw_embedded_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/ota_embedded_panel.dart';
import 'launcher_app_area.dart';

class LauncherBotShell extends StatefulWidget {
  const LauncherBotShell({
    super.key,
    required this.registry,
    required this.rosUrl,
    required this.rosStatus,
    required this.onRosUrlChanged,
    this.initialAppId,
    this.panelBuilder,
  });

  final PluginRegistry registry;
  final Uri rosUrl;
  final String rosStatus;
  final Future<void> Function(Uri rosUrl) onRosUrlChanged;
  final String? initialAppId;
  final AppPanelBuilder? panelBuilder;

  @override
  State<LauncherBotShell> createState() => _LauncherBotShellState();
}

class _LauncherBotShellState extends State<LauncherBotShell> {
  late String? _selectedAppId;
  late NluRouter _nluRouter;
  late LauncherBotController _launcherBotController;
  bool _aiMode = true;
  bool _assistantOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedAppId = widget.initialAppId;
    _nluRouter = NluRouter(widget.registry.apps);
    _launcherBotController = LauncherBotController(
      nluRouter: _nluRouter,
      aiService: GemmaLauncherBotAiService(),
      onOpenApp: _openApp,
      onCloseApp: _closeApp,
      onOpenSettings: _openSettings,
    );
  }

  @override
  void didUpdateWidget(covariant LauncherBotShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      _nluRouter = NluRouter(widget.registry.apps);
      _launcherBotController.updateRouter(_nluRouter);
    }
  }

  @override
  void dispose() {
    _launcherBotController.dispose();
    super.dispose();
  }

  AppManifest? get _selectedApp {
    final id = _selectedAppId;
    if (id == null) return null;
    for (final app in widget.registry.apps) {
      if (app.id == id) return app;
    }
    return null;
  }

  String get _title => _selectedApp?.name ?? 'Launcher';

  String get _subtitle {
    final app = _selectedApp;
    if (app == null) return 'Home surface';
    return '${app.category} · v${app.version}';
  }

  void _setAiMode(bool value) {
    setState(() {
      _aiMode = value;
      if (!value) _assistantOpen = false;
    });
  }

  void _openApp(AppManifest app) {
    setState(() => _selectedAppId = app.id);
  }

  void _openSettings() {
    setState(() => _selectedAppId = _SettingsPage.appId);
  }

  void _closeApp() {
    setState(() => _selectedAppId = null);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedApp;
    final settingsOpen = _selectedAppId == _SettingsPage.appId;
    final canClose = selected != null || settingsOpen;
    final selectedName =
        settingsOpen ? 'Settings' : selected?.name ?? 'Launcher';
    _launcherBotController.updateContext(selectedName);

    return Scaffold(
      key: const Key('launcher_bot_shell'),
      backgroundColor: _BotColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: settingsOpen ? 'Settings' : _title,
              subtitle: settingsOpen ? 'System setup' : _subtitle,
              icon: settingsOpen
                  ? Icons.settings_outlined
                  : _iconFor(selected?.id),
              aiMode: _aiMode,
              canClose: canClose,
              onClose: _closeApp,
              onModeChanged: _setAiMode,
            ),
            Expanded(
              child: Row(
                children: [
                  _AppRail(
                    aiMode: _aiMode,
                    assistantOpen: _assistantOpen,
                    onAssistantToggle: () {
                      setState(() => _assistantOpen = !_assistantOpen);
                    },
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: _aiMode && _assistantOpen ? 440 : 0,
                    child: ClipRect(
                      child: LauncherBotPanel(
                        controller: _launcherBotController,
                        selectedName: selectedName,
                        onClose: () => setState(() => _assistantOpen = false),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _AppStage(
                      apps: widget.registry.apps,
                      selectedAppId: _selectedAppId,
                      panelBuilder: widget.panelBuilder,
                      onAppLaunch: _openApp,
                      onSettingsLaunch: _openSettings,
                      rosUrl: widget.rosUrl,
                      rosStatus: widget.rosStatus,
                      onRosUrlChanged: widget.onRosUrlChanged,
                    ),
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

class _AppStage extends StatelessWidget {
  const _AppStage({
    required this.apps,
    required this.selectedAppId,
    required this.onAppLaunch,
    required this.onSettingsLaunch,
    required this.rosUrl,
    required this.rosStatus,
    required this.onRosUrlChanged,
    this.panelBuilder,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;
  final VoidCallback onSettingsLaunch;
  final Uri rosUrl;
  final String rosStatus;
  final Future<void> Function(Uri rosUrl) onRosUrlChanged;
  final AppPanelBuilder? panelBuilder;

  @override
  Widget build(BuildContext context) {
    final panel = _buildPanel();
    return Container(
      key: const Key('launcher_app_area'),
      color: _BotColors.canvas,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: panel,
      ),
    );
  }

  Widget _buildPanel() {
    if (selectedAppId == null) {
      return _HomeSurface(
        key: const ValueKey('home_panel'),
        apps: apps,
        onAppLaunch: onAppLaunch,
        onSettingsLaunch: onSettingsLaunch,
      );
    }
    if (selectedAppId == _SettingsPage.appId) {
      return _SettingsPage(
        key: const ValueKey('settings_panel'),
        rosUrl: rosUrl,
        rosStatus: rosStatus,
        onRosUrlChanged: onRosUrlChanged,
      );
    }

    final app = apps.firstWhere((a) => a.id == selectedAppId);
    final key = Key('app_embedded_${app.id}');
    if (panelBuilder != null) {
      return KeyedSubtree(key: key, child: panelBuilder!(app));
    }
    switch (app.id) {
      case 'ota_monitor':
        return OtaEmbeddedPanel(key: key);
      case 'adsw_monitor':
        return AdswEmbeddedPanel(key: key);
      default:
        return AppPlaceholderPanel(key: key, app: app);
    }
  }
}

class _HomeSurface extends StatelessWidget {
  const _HomeSurface({
    super.key,
    required this.apps,
    required this.onAppLaunch,
    required this.onSettingsLaunch,
  });

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;
  final VoidCallback onSettingsLaunch;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final app in apps) _LauncherCardData.fromApp(app),
      const _LauncherCardData.settings(),
    ];

    return Container(
      key: const Key('launcher_home_panel'),
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 780
              ? 2
              : constraints.maxWidth < 1120
                  ? 3
                  : 4;
          return GridView.builder(
            key: const Key('launcher_home_grid'),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2.05,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _AppCard(
                data: card,
                onTap: () {
                  if (card.app != null) {
                    onAppLaunch(card.app!);
                  } else {
                    onSettingsLaunch();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    super.key,
    required this.rosUrl,
    required this.rosStatus,
    required this.onRosUrlChanged,
  });

  static const appId = '__settings__';

  final Uri rosUrl;
  final String rosStatus;
  final Future<void> Function(Uri rosUrl) onRosUrlChanged;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _bridgeIpController;
  late final TextEditingController _portController;
  late final TextEditingController _vehicleProfileController;
  String? _errorText;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _bridgeIpController = TextEditingController(text: widget.rosUrl.host);
    _portController = TextEditingController(
      text: widget.rosUrl.hasPort ? '${widget.rosUrl.port}' : '9090',
    );
    _vehicleProfileController = TextEditingController(text: 'AGL demo target');
  }

  @override
  void didUpdateWidget(covariant _SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rosUrl != widget.rosUrl) {
      _bridgeIpController.text = widget.rosUrl.host;
      _portController.text =
          widget.rosUrl.hasPort ? '${widget.rosUrl.port}' : '9090';
    }
  }

  @override
  void dispose() {
    _bridgeIpController.dispose();
    _portController.dispose();
    _vehicleProfileController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final host = _bridgeIpController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      setState(() => _errorText = 'Enter a valid bridge IP and port.');
      return;
    }

    setState(() {
      _applying = true;
      _errorText = null;
    });
    try {
      await widget.onRosUrlChanged(Uri.parse('ws://$host:$port'));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _BotColors.canvas,
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _SettingsPanel(
                title: 'Connection',
                children: [
                  _SettingField(
                    label: 'Bridge IP address',
                    controller: _bridgeIpController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SettingField(
                    label: 'Port',
                    controller: _portController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _SettingField(
                    label: 'Vehicle profile',
                    controller: _vehicleProfileController,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _applying ? null : _apply,
                      icon: _applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_applying ? 'Applying' : 'Apply'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _SettingsPanel(
                title: 'Runtime',
                children: [
                  const _SettingStatus(label: 'AI SDK', value: 'Enabled'),
                  const SizedBox(height: 10),
                  _SettingStatus(label: 'ROS bridge', value: widget.rosStatus),
                  const SizedBox(height: 10),
                  const _SettingStatus(label: 'Input method', value: 'Shared'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.aiMode,
    required this.canClose,
    required this.onClose,
    required this.onModeChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool aiMode;
  final bool canClose;
  final VoidCallback onClose;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: _BotColors.surface,
        border: Border(bottom: BorderSide(color: _BotColors.line)),
      ),
      child: Row(
        children: [
          const Text(
            'AGL',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 4.2,
              color: _BotColors.ink,
            ),
          ),
          const SizedBox(width: 18),
          Container(width: 1, height: 24, color: _BotColors.line),
          const SizedBox(width: 18),
          Icon(icon, size: 20, color: _BotColors.ink),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BotColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _BotColors.muted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          if (canClose) ...[
            _CloseAppButton(onTap: onClose),
            const SizedBox(width: 10),
          ],
          _ModeButton(
            label: 'Standard',
            active: !aiMode,
            onTap: () => onModeChanged(false),
          ),
          const SizedBox(width: 8),
          _ModeButton(
            label: 'AI SDK',
            active: aiMode,
            onTap: () => onModeChanged(true),
          ),
        ],
      ),
    );
  }
}

class _AppRail extends StatelessWidget {
  const _AppRail({
    required this.aiMode,
    required this.assistantOpen,
    required this.onAssistantToggle,
  });

  final bool aiMode;
  final bool assistantOpen;
  final VoidCallback onAssistantToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: const BoxDecoration(
        color: _BotColors.rail,
        border: Border(right: BorderSide(color: _BotColors.line)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _BotColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _BotColors.line),
            ),
            child: const Text(
              'AGL',
              style: TextStyle(
                color: _BotColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const Spacer(),
          if (aiMode)
            _RailMicButton(active: assistantOpen, onTap: onAssistantToggle)
          else
            const _RailUtility(icon: Icons.volume_up_outlined),
          const SizedBox(height: 8),
          const _RailUtility(icon: Icons.power_settings_new),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.data, required this.onTap});

  final _LauncherCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('home_cat_card_${data.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _BotColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _BotColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: data.emojiIcon != null
                    ? Text(
                        data.emojiIcon!,
                        style: const TextStyle(fontSize: 28),
                      )
                    : Icon(data.icon, color: data.color, size: 30),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BotColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _BotColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _BotColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _BotColors.surface,
        border: Border.all(color: _BotColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _BotColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  const _SettingField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: Key('settings_field_$label'),
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.keyboard_outlined),
        filled: true,
        fillColor: _BotColors.canvas,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BotColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _BotColors.accent),
        ),
      ),
    );
  }
}

class _SettingStatus extends StatelessWidget {
  const _SettingStatus({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _BotColors.canvas,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _BotColors.line),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _BotColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: _BotColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 36,
        width: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _BotColors.ink : _BotColors.canvas,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? _BotColors.ink : _BotColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _BotColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RailUtility extends StatelessWidget {
  const _RailUtility({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 46,
      decoration: BoxDecoration(
        color: _BotColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _BotColors.line),
      ),
      child: Icon(icon, color: _BotColors.muted, size: 20),
    );
  }
}

class _RailMicButton extends StatelessWidget {
  const _RailMicButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Hide Launcher Bot' : 'Open Launcher Bot',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: active ? _BotColors.ink : _BotColors.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            active ? Icons.close : Icons.mic_none,
            color: Colors.white,
            size: active ? 24 : 30,
          ),
        ),
      ),
    );
  }
}

class _CloseAppButton extends StatelessWidget {
  const _CloseAppButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close app',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _BotColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _BotColors.line),
          ),
          child: const Icon(Icons.close, color: _BotColors.ink, size: 22),
        ),
      ),
    );
  }
}

class _LauncherCardData {
  const _LauncherCardData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.emojiIcon,
    this.app,
  });

  factory _LauncherCardData.fromApp(AppManifest app) {
    return _LauncherCardData(
      id: app.id,
      name: app.name,
      subtitle: app.category,
      icon: _iconFor(app.id),
      color: _parseHex(app.color),
      emojiIcon: app.icon.length <= 2 ? app.icon : null,
      app: app,
    );
  }

  const _LauncherCardData.settings()
      : id = _SettingsPage.appId,
        name = 'Settings',
        subtitle = 'System setup',
        icon = Icons.settings_outlined,
        color = _BotColors.ink,
        emojiIcon = null,
        app = null;

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? emojiIcon;
  final AppManifest? app;
}

IconData _iconFor(String? appId) {
  switch (appId) {
    case 'ota_monitor':
      return Icons.system_update_alt;
    case 'adsw_monitor':
      return Icons.sensors_outlined;
    case _SettingsPage.appId:
      return Icons.settings_outlined;
    default:
      return Icons.apps_outlined;
  }
}

Color _parseHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  if (normalized.length != 6) return _BotColors.accent;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return _BotColors.accent;
  return Color(0xFF000000 | value);
}

abstract final class _BotColors {
  static const canvas = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const rail = Color(0xFFE8ECF1);
  static const ink = Color(0xFF15191F);
  static const muted = Color(0xFF65707C);
  static const line = Color(0xFFDDE3EA);
  static const accent = Color(0xFF2E6BE6);
}
