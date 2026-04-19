import 'package:flutter/material.dart';
import '../theme/launcher_tokens.dart';
import '../theme/app_accent_scope.dart';

/// Chat bubble widget for AI and user messages.
/// Supports slide-fade animation on entry.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    this.isAi = true,
    this.animate = true,
  });

  final String text;
  final bool isAi;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final accent = AppAccentScope.of(context);

    Widget bubble = Container(
      key: isAi ? const Key('chat_bubble_ai') : const Key('chat_bubble_user'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isAi ? LauncherTokens.bg3 : LauncherTokens.bg4,
        border: isAi
            ? Border(left: BorderSide(color: accent, width: 3))
            : Border.all(color: LauncherTokens.b2),
        borderRadius: isAi
            ? const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
        boxShadow: isAi
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * (isAi ? 0.86 : 0.70),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: LauncherTokens.fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: LauncherTokens.t1,
        ),
      ),
    );

    if (isAi == false) {
      bubble = Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    if (!animate) return bubble;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 7 * (1 - value)),
            child: child,
          ),
        );
      },
      child: bubble,
    );
  }
}
