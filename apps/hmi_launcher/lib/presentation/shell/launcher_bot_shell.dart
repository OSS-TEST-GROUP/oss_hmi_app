import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../../domain/nlu_router.dart';
import '../../domain/plugin_registry.dart';
import '../panels/adsw_embedded_panel.dart';
import '../panels/app_placeholder_panel.dart';
import '../panels/ota_embedded_panel.dart';
import 'launcher_app_area.dart';

class LauncherBotShell extends StatefulWidget {
  const LauncherBotShell({
    super.key,
    required this.registry,
    this.initialAppId,
    this.panelBuilder,
  });

  final PluginRegistry registry;
  final String? initialAppId;
  final AppPanelBuilder? panelBuilder;

  @override
  State<LauncherBotShell> createState() => _LauncherBotShellState();
}

class _LauncherBotShellState extends State<LauncherBotShell> {
  final TextEditingController _botController = TextEditingController();

  late String? _selectedAppId;
  late NluRouter _nluRouter;
  bool _aiMode = true;
  bool _assistantOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedAppId = widget.initialAppId;
    _nluRouter = NluRouter(widget.registry.apps);
  }

  @override
  void didUpdateWidget(covariant LauncherBotShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      _nluRouter = NluRouter(widget.registry.apps);
    }
  }

  @override
  void dispose() {
    _botController.dispose();
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

  void _submitBotCommand(String value) {
    final input = value.trim();
    if (input.isEmpty) return;
    _botController.clear();

    if (_isCloseCommand(input)) {
      if (_selectedAppId != null) _closeApp();
      _showToast('Closed app');
      return;
    }

    final match = _nluRouter.resolve(input);
    if (match != null) {
      _openApp(match);
      _showToast('Opened ${match.name}');
      return;
    }

    if (input.toLowerCase().contains('settings') || input.contains('설정')) {
      _openSettings();
      _showToast('Opened Settings');
      return;
    }

    final hints = widget.registry.apps.map((a) => a.name).take(3).join(', ');
    _showToast('"$input" - try: $hints');
  }

  bool _isCloseCommand(String input) {
    const commands = {
      'close',
      'close app',
      'exit',
      'exit app',
      'quit',
      'back',
      'home',
      'go home',
      'back to home',
      '홈',
      '홈으로',
      '닫기',
      '닫아',
      '닫아줘',
      '종료',
      '나가기',
      '뒤로',
      '뒤로 가기',
    };
    return commands.contains(input.trim().toLowerCase());
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _BotColors.ink,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedApp;
    final settingsOpen = _selectedAppId == _SettingsPage.appId;
    final canClose = selected != null || settingsOpen;

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
                      child: _AssistantPanel(
                        apps: widget.registry.apps,
                        selectedName: settingsOpen
                            ? 'Settings'
                            : selected?.name ?? 'Launcher',
                        controller: _botController,
                        onClose: () => setState(() => _assistantOpen = false),
                        onSubmit: _submitBotCommand,
                        onOpenFirstApp: widget.registry.apps.isEmpty
                            ? null
                            : () => _openApp(widget.registry.apps.first),
                        onAnalyze: () => _showToast('Analysis requested'),
                        onAlerts: () => _showToast('No active warnings'),
                        onSummary: () => _showToast('Summary requested'),
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
    this.panelBuilder,
  });

  final List<AppManifest> apps;
  final String? selectedAppId;
  final ValueChanged<AppManifest> onAppLaunch;
  final VoidCallback onSettingsLaunch;
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
      return const _SettingsPage(key: ValueKey('settings_panel'));
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

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({super.key});

  static const appId = '__settings__';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _BotColors.canvas,
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              flex: 6,
              child: _SettingsPanel(
                title: 'Connection',
                children: [
                  _SettingField(
                    label: 'Bridge IP address',
                    initialValue: '192.168.0.10',
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SizedBox(height: 12),
                  _SettingField(
                    label: 'Port',
                    initialValue: '9090',
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  _SettingField(
                    label: 'Vehicle profile',
                    initialValue: 'AGL demo target',
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _SettingsPanel(
                title: 'Runtime',
                children: [
                  _SettingStatus(label: 'AI SDK', value: 'Enabled'),
                  SizedBox(height: 10),
                  _SettingStatus(label: 'ROS bridge', value: 'Ready'),
                  SizedBox(height: 10),
                  _SettingStatus(label: 'Input method', value: 'Shared'),
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

class _AssistantPanel extends StatelessWidget {
  const _AssistantPanel({
    required this.apps,
    required this.selectedName,
    required this.controller,
    required this.onClose,
    required this.onSubmit,
    required this.onAnalyze,
    required this.onAlerts,
    required this.onSummary,
    this.onOpenFirstApp,
  });

  final List<AppManifest> apps;
  final String selectedName;
  final TextEditingController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onOpenFirstApp;
  final VoidCallback onAnalyze;
  final VoidCallback onAlerts;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: _BotColors.surface,
        border: Border(right: BorderSide(color: _BotColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AssistantHeader(selectedName: selectedName, onClose: onClose),
          const SizedBox(height: 12),
          Expanded(child: _AssistantHistory(selectedName: selectedName)),
          const SizedBox(height: 12),
          _BotInput(controller: controller, onSubmit: onSubmit),
          const SizedBox(height: 8),
          _QuickCommandRow(
            onOpen: onOpenFirstApp,
            onAnalyze: onAnalyze,
            onAlerts: onAlerts,
            onSummary: onSummary,
          ),
        ],
      ),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.selectedName, required this.onClose});

  final String selectedName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _BotColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BotColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _BotColors.accent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Launcher Bot',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _BotColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Context: $selectedName',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BotColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.chevron_left, color: _BotColors.ink),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _AssistantHistory extends StatelessWidget {
  const _AssistantHistory({required this.selectedName});

  final String selectedName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: BoxDecoration(
        color: _BotColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BotColors.line),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        children: [
          const _MessageLine(
            bot: true,
            text:
                'Launcher Bot is listening. I can open apps, check monitor state, and summarize alerts.',
          ),
          _CommandLine(command: 'Analyze', target: selectedName),
          _MessageLine(
            bot: true,
            text:
                '$selectedName looks ready. Runtime is connected and there are no blocking alerts.',
          ),
          const _CommandLine(command: 'Alerts', target: 'AD SW Monitor'),
          const _MessageLine(
            bot: true,
            text: 'No active warnings. Last heartbeat arrived 1 second ago.',
          ),
        ],
      ),
    );
  }
}

class _BotInput extends StatelessWidget {
  const _BotInput({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('launcher_bot_input_field'),
      controller: controller,
      onSubmitted: onSubmit,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.keyboard_outlined, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () => onSubmit(controller.text),
        ),
        hintText: 'Tap to type',
        hintStyle: const TextStyle(
          color: _BotColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: _BotColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _BotColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _BotColors.accent),
        ),
      ),
    );
  }
}

class _QuickCommandRow extends StatelessWidget {
  const _QuickCommandRow({
    required this.onOpen,
    required this.onAnalyze,
    required this.onAlerts,
    required this.onSummary,
  });

  final VoidCallback? onOpen;
  final VoidCallback onAnalyze;
  final VoidCallback onAlerts;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) {
    final commands = [
      _CommandSpec(Icons.apps, 'Open', onOpen),
      _CommandSpec(Icons.monitor_heart_outlined, 'Analyze', onAnalyze),
      _CommandSpec(Icons.warning_amber_outlined, 'Alerts', onAlerts),
      _CommandSpec(Icons.summarize_outlined, 'Summary', onSummary),
    ];
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _BotColors.canvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _BotColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < commands.length; i++) ...[
            Expanded(child: _CommandChip(spec: commands[i])),
            if (i != commands.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _CommandChip extends StatelessWidget {
  const _CommandChip({required this.spec});

  final _CommandSpec spec;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: spec.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _BotColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _BotColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(spec.icon, color: _BotColors.accent, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                spec.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BotColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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
    required this.initialValue,
    this.keyboardType,
  });

  final String label;
  final String initialValue;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: Key('settings_field_$label'),
      initialValue: initialValue,
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

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.bot, required this.text});

  final bool bot;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: bot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: bot ? _BotColors.surface : _BotColors.ink,
          borderRadius: BorderRadius.circular(12),
          border: bot ? Border.all(color: _BotColors.line) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: bot ? _BotColors.ink : Colors.white,
            height: 1.32,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CommandLine extends StatelessWidget {
  const _CommandLine({required this.command, required this.target});

  final String command;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: _BotColors.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _BotColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                command,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                target,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
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

class _CommandSpec {
  const _CommandSpec(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
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
