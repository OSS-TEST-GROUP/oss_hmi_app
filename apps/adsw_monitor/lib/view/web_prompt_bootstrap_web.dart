// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';

class WebPromptBootstrap extends StatefulWidget {
  const WebPromptBootstrap({
    super.key,
    required this.onConfigured,
    required this.child,
  });

  final Future<void> Function(Uri rosUrl) onConfigured;
  final Widget child;

  @override
  State<WebPromptBootstrap> createState() => _WebPromptBootstrapState();
}

class _WebPromptBootstrapState extends State<WebPromptBootstrap> {
  static const _kRosUrlKey = 'adsw.rosUrl';
  final _controller = TextEditingController(text: 'ws://127.0.0.1:9090');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final saved = html.window.localStorage[_kRosUrlKey];
    if (saved != null && saved.isNotEmpty) {
      _boot(Uri.parse(saved));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDialog());
    }
  }

  Future<void> _boot(Uri rosUrl) async {
    await widget.onConfigured(rosUrl);
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _openDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ROS Bridge 주소 입력'),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'ws://<호스트>:9090',
            labelText: 'WebSocket URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final txt = _controller.text.trim();
              if (txt.isEmpty) return;
              Uri? uri;
              try { uri = Uri.parse(txt); } catch (_) {}
              if (uri == null || !uri.hasScheme) return;

              html.window.localStorage[_kRosUrlKey] = uri.toString();
              Navigator.of(ctx).pop();
              _boot(uri);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Material(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.child;
  }
}
