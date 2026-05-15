enum LauncherBotSpeaker { user, bot }

class LauncherBotMessage {
  const LauncherBotMessage({
    required this.speaker,
    required this.text,
    required this.timestamp,
    this.intent,
  });

  final LauncherBotSpeaker speaker;
  final String text;
  final String timestamp;
  final String? intent;

  bool get isBot => speaker == LauncherBotSpeaker.bot;

  LauncherBotMessage copyWith({
    LauncherBotSpeaker? speaker,
    String? text,
    String? timestamp,
    String? intent,
  }) {
    return LauncherBotMessage(
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      intent: intent ?? this.intent,
    );
  }
}
