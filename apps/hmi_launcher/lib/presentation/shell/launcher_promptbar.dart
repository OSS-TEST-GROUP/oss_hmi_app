import 'package:flutter/material.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Prompt input bar with mic button, text field, and send button.
/// Height: 60px (fixed via LauncherTokens.promptbarHeight).
class LauncherPromptBar extends StatefulWidget {
  const LauncherPromptBar({
    super.key,
    required this.onSubmit,
    this.placeholder = 'Enter app name or query...',
  });

  final ValueChanged<String> onSubmit;
  final String placeholder;

  @override
  State<LauncherPromptBar> createState() => _LauncherPromptBarState();
}

class _LauncherPromptBarState extends State<LauncherPromptBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isMicHovered = false;

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    return Container(
      key: const Key('launcher_promptbar'),
      height: LauncherTokens.promptbarHeight,
      decoration: BoxDecoration(
        color: LauncherTokens.bg2,
        border: Border(top: BorderSide(color: LauncherTokens.b1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isMicHovered = true),
            onExit: (_) => setState(() => _isMicHovered = false),
            child: GestureDetector(
              onTap: () {
                // Mic functionality placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice input not implemented yet'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: AnimatedScale(
                key: const Key('promptbar_mic'),
                scale: _isMicHovered ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: const Text(
                  '🎙',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('prompt_input_field'),
              controller: _controller,
              style: TextStyle(
                fontFamily: LauncherTokens.fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: LauncherTokens.t1,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: TextStyle(
                  color: LauncherTokens.t3,
                  fontFamily: LauncherTokens.fontBody,
                ),
                filled: true,
                fillColor: LauncherTokens.bg3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: LauncherTokens.b1, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: LauncherTokens.b1, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 0,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _handleSubmit,
            child: Container(
              key: const Key('promptbar_send_button'),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.25),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_upward,
                color: LauncherTokens.bg0,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
