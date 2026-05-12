import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class QuickPromptBar extends StatelessWidget {
  const QuickPromptBar({
    super.key,
    required this.compact,
    required this.prompts,
    required this.onPromptTap,
    required this.onMetricsTap,
  });

  final bool compact;
  final List<QuickPrompt> prompts;
  final ValueChanged<QuickPrompt> onPromptTap;
  final VoidCallback onMetricsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? null : 56,
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prompts
                        .map(
                          (prompt) => _QuickPromptButton(
                            prompt: prompt,
                            onTap: () => onPromptTap(prompt),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                _MetricsButton(onTap: onMetricsTap),
              ],
            )
          : Row(
              children: [
                ...prompts.map(
                  (prompt) => Padding(
                    padding: EdgeInsets.only(
                      right: prompt == prompts.last ? 0 : 8,
                    ),
                    child: _QuickPromptButton(
                      prompt: prompt,
                      onTap: () => onPromptTap(prompt),
                    ),
                  ),
                ),
                const Spacer(),
                _MetricsButton(onTap: onMetricsTap),
              ],
            ),
    );
  }
}

class _QuickPromptButton extends StatelessWidget {
  const _QuickPromptButton({required this.prompt, required this.onTap});

  final QuickPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Ink(
        width: 156,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: const Color(0xFFF4F4F4),
        ),
        child: Row(
          children: [
            Icon(prompt.icon, color: const Color(0xFF393C41), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                prompt.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF171A20),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF5C5E62),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsButton extends StatelessWidget {
  const _MetricsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.monitor_heart_outlined),
        color: const Color(0xFF171A20),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF4F4F4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}
