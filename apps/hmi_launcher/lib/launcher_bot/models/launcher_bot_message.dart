enum LauncherBotSpeaker { user, bot }

class LauncherBotMessageAction {
  const LauncherBotMessageAction({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class LauncherBotMessage {
  const LauncherBotMessage({
    required this.speaker,
    required this.text,
    required this.timestamp,
    this.intent,
    this.actions = const [],
  });

  final LauncherBotSpeaker speaker;
  final String text;
  final String timestamp;
  final String? intent;
  final List<LauncherBotMessageAction> actions;

  bool get isBot => speaker == LauncherBotSpeaker.bot;

  LauncherBotMessage copyWith({
    LauncherBotSpeaker? speaker,
    String? text,
    String? timestamp,
    String? intent,
    List<LauncherBotMessageAction>? actions,
  }) {
    return LauncherBotMessage(
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      intent: intent ?? this.intent,
      actions: actions ?? this.actions,
    );
  }
}
