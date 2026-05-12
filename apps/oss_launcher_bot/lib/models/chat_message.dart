import 'package:flutter/material.dart';

enum ChatSpeaker { bot, user }

class ChatMessage {
  const ChatMessage({
    required this.speaker,
    required this.title,
    required this.message,
    required this.timestamp,
    this.intent,
  });

  final ChatSpeaker speaker;
  final String title;
  final String message;
  final String timestamp;
  final String? intent;
}

class QuickPrompt {
  const QuickPrompt({
    required this.label,
    required this.command,
    required this.icon,
  });

  final String label;
  final String command;
  final IconData icon;
}
