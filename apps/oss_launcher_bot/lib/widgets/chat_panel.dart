import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import 'message_bubble.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.controller,
    required this.messages,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '대화',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF171A20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map(
                  (suggestion) => ActionChip(
                    onPressed: () => onSuggestionTap(suggestion),
                    backgroundColor: const Color(0xFFF4F4F4),
                    surfaceTintColor: Colors.transparent,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        color: Color(0xFF393C41),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return MessageBubble(message: messages[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
