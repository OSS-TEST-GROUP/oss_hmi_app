import 'package:flutter/material.dart';
import '../../domain/app_manifest.dart';
import '../widgets/quick_chip_row.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/app_launch_card.dart';

/// Home panel for the launcher with quick chips, chat bubbles, and app launch cards.
class LauncherHomePanel extends StatefulWidget {
  const LauncherHomePanel({
    super.key,
    required this.apps,
    required this.onAppLaunch,
  });

  final List<AppManifest> apps;
  final ValueChanged<AppManifest> onAppLaunch;

  @override
  State<LauncherHomePanel> createState() => LauncherHomePanelState();
}

/// Public state class to allow parent to call handlePromptSubmit.
class LauncherHomePanelState extends State<LauncherHomePanel> {
  final List<Widget> _chatMessages = [];
  final ScrollController _scrollController = ScrollController();
  AppManifest? _matchedApp;

  @override
  void initState() {
    super.initState();
    _chatMessages.add(
      const ChatBubble(
        text: 'Which app would you like to launch? 💬',
        isAi: true,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleQuickChipTap(AppManifest app) {
    setState(() {
      _matchedApp = app;
      _chatMessages.add(
        ChatBubble(
          text: 'Launch ${app.name}',
          isAi: false,
        ),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Called from parent when prompt is submitted.
  void handlePromptSubmit(String userInput, AppManifest? matchedApp) {
    setState(() {
      _chatMessages.add(
        ChatBubble(
          text: userInput,
          isAi: false,
        ),
      );

      if (matchedApp != null) {
        _matchedApp = matchedApp;
      } else {
        _chatMessages.add(
          const ChatBubble(
            text: 'No matching app found. Try: adsw_monitor, ota_monitor',
            isAi: true,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('launcher_home_panel'),
      children: [
        QuickChipRow(
          apps: widget.apps,
          onAppSelected: _handleQuickChipTap,
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(18),
            itemCount: _chatMessages.length + (_matchedApp != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _chatMessages.length) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _chatMessages[index],
                );
              } else {
                // Show app launch card at the end
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppLaunchCard(
                    app: _matchedApp!,
                    onLaunch: () => widget.onAppLaunch(_matchedApp!),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
