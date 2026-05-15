import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isBot = message.speaker == ChatSpeaker.bot;

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isBot ? const Color(0xFFF4F4F4) : const Color(0xFF3E6AE1),
            border: Border.all(
              color: isBot ? const Color(0xFFEEEEEE) : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    message.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isBot ? const Color(0xFF171A20) : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    message.timestamp,
                    style: TextStyle(
                      fontSize: 14,
                      color: isBot
                          ? const Color(0xFF5C5E62)
                          : const Color(0xD9FFFFFF),
                    ),
                  ),
                  if (message.intent != null) ...[
                    const SizedBox(width: 10),
                    _IntentPill(label: message.intent!),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.43,
                  fontWeight: FontWeight.w400,
                  color: isBot ? const Color(0xFF393C41) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentPill extends StatelessWidget {
  const _IntentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFFFFFFFF),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF5C5E62),
        ),
      ),
    );
  }
}
