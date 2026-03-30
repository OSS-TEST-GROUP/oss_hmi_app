import 'package:flutter/material.dart';

/// 네이티브 플랫폼에서는 그냥 child를 바로 보여주는 스텁
class WebPromptBootstrap extends StatelessWidget {
  const WebPromptBootstrap({
    super.key,
    required this.onConfigured,
    required this.child,
  });

  final Future<void> Function(Uri rosUrl) onConfigured; // 웹 전용 훅, 여기선 미사용
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
