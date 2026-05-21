import 'package:flutter/material.dart';

import '../../domain/app_manifest.dart';
import '../../launcher_bot/models/launcher_bot_message.dart';
import '../../launcher_bot/services/launcher_bot_controller.dart';

class LauncherBotPanel extends StatefulWidget {
  const LauncherBotPanel({
    super.key,
    required this.controller,
    required this.selectedName,
    required this.aiMode,
    required this.apps,
    required this.onClose,
  });

  final LauncherBotController controller;
  final String selectedName;
  final bool aiMode;
  final List<AppManifest> apps;
  final VoidCallback onClose;

  @override
  State<LauncherBotPanel> createState() => _LauncherBotPanelState();
}

class _LauncherBotPanelState extends State<LauncherBotPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant LauncherBotPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _submit() {
    final text = _inputController.text;
    _inputController.clear();
    widget.controller.submit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: _BotPanelColors.surface,
        border: Border(right: BorderSide(color: _BotPanelColors.line)),
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
          _PanelHeader(
            selectedName: widget.selectedName,
            aiMode: widget.aiMode,
            onClose: widget.onClose,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _MessageList(
              controller: _scrollController,
              launcherBotController: widget.controller,
              messages: widget.controller.messages,
            ),
          ),
          const SizedBox(height: 12),
          _StandardCommandPanel(
            apps: widget.apps,
            selectedName: widget.selectedName,
            controller: widget.controller,
          ),
          if (widget.aiMode) ...[
            const SizedBox(height: 8),
            _BotInput(
              controller: _inputController,
              enabled: !widget.controller.isGenerating,
              onSubmit: _submit,
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.selectedName,
    required this.aiMode,
    required this.onClose,
  });

  final String selectedName;
  final bool aiMode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _BotPanelColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BotPanelColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _BotPanelColors.accent,
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
                  'Launcher Agent',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _BotPanelColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  aiMode
                      ? 'AI SDK · Context: $selectedName'
                      : 'Standard · Local commands',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BotPanelColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.chevron_left, color: _BotPanelColors.ink),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _StandardCommandPanel extends StatelessWidget {
  const _StandardCommandPanel({
    required this.apps,
    required this.selectedName,
    required this.controller,
  });

  final List<AppManifest> apps;
  final String selectedName;
  final LauncherBotController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _BotPanelColors.canvas,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _BotPanelColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Local commands',
            style: TextStyle(
              color: _BotPanelColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final app in apps)
                _StandardCommandChip(
                  label: '${app.name} 실행',
                  icon: _iconForAppId(app.id),
                  onTap: () =>
                      controller.submitLocalCommand('${app.name} 실행해줘'),
                ),
              _StandardCommandChip(
                label: '설정 열기',
                icon: Icons.settings_outlined,
                onTap: () => controller.submitLocalCommand('설정 열어줘'),
              ),
              if (selectedName != 'Launcher')
                _StandardCommandChip(
                  label: '현재 앱 닫기',
                  icon: Icons.close,
                  onTap: () => controller.submitLocalCommand('닫아줘'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _iconForAppId(String id) {
  switch (id) {
    case 'ota_monitor':
      return Icons.inventory_2_outlined;
    case 'adsw_monitor':
      return Icons.satellite_alt_outlined;
    default:
      return Icons.apps_outlined;
  }
}

class _StandardCommandChip extends StatelessWidget {
  const _StandardCommandChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _BotPanelColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _BotPanelColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _BotPanelColors.accent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _BotPanelColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.launcherBotController,
    required this.messages,
  });

  final ScrollController controller;
  final LauncherBotController launcherBotController;
  final List<LauncherBotMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: BoxDecoration(
        color: _BotPanelColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _BotPanelColors.line),
      ),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          return _MessageBubble(
            message: messages[index],
            controller: launcherBotController,
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.controller});

  final LauncherBotMessage message;
  final LauncherBotController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: message.isBot ? _BotPanelColors.surface : _BotPanelColors.ink,
          borderRadius: BorderRadius.circular(12),
          border:
              message.isBot ? Border.all(color: _BotPanelColors.line) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.intent != null) ...[
              Text(
                message.intent!,
                style: TextStyle(
                  color: message.isBot ? _BotPanelColors.accent : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.text,
              style: TextStyle(
                color: message.isBot ? _BotPanelColors.ink : Colors.white,
                height: 1.32,
                fontSize: 13,
              ),
            ),
            if (message.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in message.actions)
                    _SuggestionActionButton(
                      action: action,
                      enabled: controller.pendingSuggestionAppId != null,
                      onTap: () {
                        if (action.id == 'accept_suggestion') {
                          controller.acceptSuggestion();
                        } else if (action.id == 'decline_suggestion') {
                          controller.declineSuggestion();
                        }
                      },
                    ),
                ],
              ),
            ],
            if (message.details != null) ...[
              const SizedBox(height: 8),
              Text(
                message.details!,
                style: TextStyle(
                  color: message.isBot
                      ? _BotPanelColors.muted
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionActionButton extends StatelessWidget {
  const _SuggestionActionButton({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final LauncherBotMessageAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPositive = action.id == 'accept_suggestion';
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: enabled && isPositive
              ? _BotPanelColors.accent
              : _BotPanelColors.canvas,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: enabled && isPositive
                ? _BotPanelColors.accent
                : _BotPanelColors.line,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          action.label,
          style: TextStyle(
            color: enabled && isPositive ? Colors.white : _BotPanelColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BotInput extends StatelessWidget {
  const _BotInput({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('launcher_bot_input_field'),
      controller: controller,
      enabled: enabled,
      onSubmitted: (_) => onSubmit(),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.keyboard_outlined, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: enabled ? onSubmit : null,
        ),
        hintText: enabled ? 'Tap to type' : '답변 생성중...',
        hintStyle: const TextStyle(
          color: _BotPanelColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: _BotPanelColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _BotPanelColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _BotPanelColors.accent),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _BotPanelColors.line),
        ),
      ),
    );
  }
}

abstract final class _BotPanelColors {
  static const canvas = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15191F);
  static const muted = Color(0xFF65707C);
  static const line = Color(0xFFDDE3EA);
  static const accent = Color(0xFF2E6BE6);
}
