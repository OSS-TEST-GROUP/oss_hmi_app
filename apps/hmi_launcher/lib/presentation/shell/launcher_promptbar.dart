import 'package:flutter/material.dart';

import '../theme/launcher_tokens.dart';

/// Quick-chip entry: an action the user can trigger with one tap above
/// the prompt input.
class PromptChip {
  const PromptChip({required this.label, this.appId, this.query});

  /// Visible text on the chip.
  final String label;

  /// If set, tapping the chip launches this plugin directly.
  final String? appId;

  /// Prompt text sent to the NLU router when tapped. Used when [appId]
  /// is not set — lets the router decide what to open.
  final String? query;
}

/// Tesla-style prompt bar: the primary entry point of the launcher.
///
/// Layout: optional chips row on top, then a single-line input framed by
/// a mic button, "Ask AGL" brand tag, divider, text field, and send
/// button. Sits at the bottom of the shell.
class LauncherPromptBar extends StatefulWidget {
  const LauncherPromptBar({
    super.key,
    required this.onSubmit,
    this.chips = const [],
    this.onChip,
    this.placeholder = 'Ask AGL — "open OTA", "show sensor health"…',
  });

  final ValueChanged<String> onSubmit;
  final List<PromptChip> chips;
  final ValueChanged<PromptChip>? onChip;
  final String placeholder;

  @override
  State<LauncherPromptBar> createState() => _LauncherPromptBarState();
}

class _LauncherPromptBarState extends State<LauncherPromptBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('launcher_promptbar'),
      decoration: const BoxDecoration(
        color: LauncherTokens.bg0,
        border: Border(top: BorderSide(color: LauncherTokens.b1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.chips.isNotEmpty) ...[
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.chips.length,
                // Wildcard pattern (_, _) needs Dart 3.7+; the AGL SDK
                // currently ships Dart 3.5, so keep the traditional
                // double-underscore alias.
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = widget.chips[i];
                  return _Chip(
                    label: c.label,
                    onTap: () => widget.onChip?.call(c),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            focused: _focused,
            placeholder: widget.placeholder,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final border = _hover ? LauncherTokens.t1 : LauncherTokens.b2;
    final fg = _hover ? LauncherTokens.t1 : LauncherTokens.t2;
    final bg = _hover ? LauncherTokens.bg3 : LauncherTokens.bg0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 330),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.placeholder,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String placeholder;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 330),
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: LauncherTokens.bg0,
        border: Border.all(
          color: focused ? LauncherTokens.accent : LauncherTokens.b2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          _IconButton(
            icon: Icons.mic_none,
            onTap: () {},
            semanticLabel: 'Voice input',
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome,
                  size: 14, color: LauncherTokens.accent),
              SizedBox(width: 6),
              Text(
                'Ask AGL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: LauncherTokens.t1,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 20, color: LauncherTokens.b1),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('prompt_input_field'),
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 14,
                color: LauncherTokens.t1,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(color: LauncherTokens.tHint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(onTap: onSubmit),
        ],
      ),
    );
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 330),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover ? LauncherTokens.bg3 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 18,
            color: LauncherTokens.t1,
            semanticLabel: widget.semanticLabel,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          key: const Key('promptbar_send_button'),
          duration: const Duration(milliseconds: 330),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hover
                ? LauncherTokens.accentHover
                : LauncherTokens.accent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_forward,
            size: 16,
            color: LauncherTokens.bg0,
          ),
        ),
      ),
    );
  }
}
