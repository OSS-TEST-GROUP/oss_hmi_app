import 'package:flutter/material.dart';

/// Stub that simply shows its child on native platforms.
class WebPromptBootstrap extends StatelessWidget {
  const WebPromptBootstrap({
    super.key,
    required this.onConfigured,
    required this.child,
  });

  final Future<void> Function(Uri rosUrl) onConfigured; // web-only hook, unused here
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
