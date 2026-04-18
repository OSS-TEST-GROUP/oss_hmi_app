import 'package:flutter/material.dart';

/// Always-pinned text input bar (Zone 4, covers F-01 in the plan).
///
/// The bar is controlled — parent owns the current text via [controller]
/// and reacts to [onSubmitted]. Pressing Enter or tapping the send icon
/// fires the callback and clears the field.
class PromptInputBar extends StatelessWidget {
  const PromptInputBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hintText = '명령을 입력하세요...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final String hintText;

  void _submit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    onSubmitted(text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.mic_none, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('prompt_input_field'),
              controller: controller,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            key: const Key('prompt_submit_button'),
            icon: const Icon(Icons.arrow_upward, size: 20),
            color: const Color(0xFF94A3B8),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
