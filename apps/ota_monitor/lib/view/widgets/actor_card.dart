import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/theme/app_palette.dart';

/// Form-style card for one OTA Actor-service request/response.
///
/// Used to live behind a header [Actor] modal launcher; now embedded
/// directly in the OtaViewPage right panel so the operator can fire
/// Actor calls without opening a dialog. Behaviour is unchanged:
///
///   - input fields (always at least app_name; SetSettings has a JSON
///     app_settings multiline field)
///   - Send button (disabled while a request is in flight or while
///     OtaCollector is not yet ready)
///   - response area showing `id / ret_code / body` on success,
///     leading ✕ on business-level error, ⚠ on the 5-second UI
///     timeout
class ActorCard extends StatefulWidget {
  const ActorCard({
    super.key,
    required this.cardKey,
    required this.title,
    required this.fields,
    required this.sendKey,
    required this.responseKey,
    required this.kind,
    required this.collector,
    this.selectedApp,
  });

  final String cardKey;
  final String title;
  final List<ActorCardField> fields;
  final String sendKey;
  final String responseKey;
  final OtaRequestKind kind;
  final OtaCollector collector;

  /// Shared notifier from the parent screen. When the user picks an app
  /// in the left list, the first field (app_name) is pre-filled here.
  final ValueNotifier<String?>? selectedApp;

  @override
  State<ActorCard> createState() => _ActorCardState();
}

/// Declarative description of one input field on an [ActorCard].
class ActorCardField {
  const ActorCardField(this.label, {required this.keyName, this.multiline = false});
  final String label;
  final String keyName;
  final bool multiline;
}

class _ActorCardState extends State<ActorCard> {
  late final List<TextEditingController> _controllers;
  StreamSubscription<OtaResponseEvent>? _sub;
  Timer? _timer;

  int? _inflightId;
  String _display = '';
  _DisplayKind _displayKind = _DisplayKind.idle;

  static const Duration _uiTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _controllers =
        widget.fields.map((_) => TextEditingController()).toList(growable: false);
    _sub = widget.collector.responses.listen(_onResponse);
    widget.collector.readyNotifier.addListener(_onReadyChange);
    final initial = widget.selectedApp?.value;
    if (initial != null && _controllers.isNotEmpty) {
      _controllers[0].text = initial;
    }
    widget.selectedApp?.addListener(_onSelectedAppChange);
  }

  void _onReadyChange() {
    if (mounted) setState(() {});
  }

  void _onSelectedAppChange() {
    final name = widget.selectedApp?.value;
    if (name != null && _controllers.isNotEmpty && mounted) {
      setState(() => _controllers[0].text = name);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    widget.selectedApp?.removeListener(_onSelectedAppChange);
    widget.collector.readyNotifier.removeListener(_onReadyChange);
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onResponse(OtaResponseEvent ev) {
    if (ev.kind != widget.kind) return;
    if (_inflightId == null || ev.id != _inflightId) return;
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    final isOk = ev.retCode == 1;
    setState(() {
      _inflightId = null;
      _display = isOk
          ? _formatResponse(ev)
          : '✕ ${_formatResponse(ev)}';
      _displayKind = isOk ? _DisplayKind.ok : _DisplayKind.businessError;
    });
  }

  String _formatResponse(OtaResponseEvent ev) {
    final buf = StringBuffer();
    buf.writeln('id: ${ev.id ?? "?"}   ret_code: ${_retLabel(ev.retCode)}');
    ev.body.forEach((k, v) {
      if (k == 'id' || k == 'ret_code') return;
      buf.writeln('$k: $v');
    });
    return buf.toString().trimRight();
  }

  static String _retLabel(int? ret) {
    switch (ret) {
      case 1:
        return 'OK';
      case 2:
        return 'ERROR';
      default:
        return ret?.toString() ?? 'unknown';
    }
  }

  bool get _canSend {
    if (_inflightId != null) return false;
    if (!widget.collector.isReady) return false;
    return _controllers.isNotEmpty &&
        _controllers.first.text.trim().isNotEmpty;
  }

  void _onSend() {
    final appName = _controllers.first.text.trim();
    if (appName.isEmpty) return;

    int id;
    switch (widget.kind) {
      case OtaRequestKind.getSettings:
        id = widget.collector.requestAppSettings(appName);
        break;
      case OtaRequestKind.setSettings:
        final value = _controllers.length > 1
            ? _controllers[1].text
            : '';
        id = widget.collector.setAppSettings(appName, value);
        break;
      case OtaRequestKind.getState:
        id = widget.collector.requestAppState(appName);
        break;
      case OtaRequestKind.setUpdate:
        id = widget.collector.requestUpdate(appName);
        break;
    }

    setState(() {
      _inflightId = id;
      _display = 'Sending...  id=$id  app=$appName';
      _displayKind = _DisplayKind.pending;
    });

    _timer?.cancel();
    _timer = Timer(_uiTimeout, () {
      if (!mounted) return;
      if (_inflightId != id) return; // response already arrived
      setState(() {
        _inflightId = null;
        _display =
            '⚠ timeout (${_uiTimeout.inSeconds}s) — id=$id  app=$appName';
        _displayKind = _DisplayKind.timeout;
      });
    });
  }

  Color? _displayColor() {
    switch (_displayKind) {
      case _DisplayKind.ok:
        return palette.success;
      case _DisplayKind.businessError:
        return palette.error;
      case _DisplayKind.timeout:
        return palette.warning;
      case _DisplayKind.pending:
      case _DisplayKind.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      key: Key(widget.cardKey),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < widget.fields.length; i++) ...[
            TextField(
              key: Key(widget.fields[i].keyName),
              controller: _controllers[i],
              enabled: _inflightId == null,
              maxLines: widget.fields[i].multiline ? 6 : 1,
              minLines: widget.fields[i].multiline ? 3 : 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: widget.fields[i].label,
                labelStyle: TextStyle(color: p.textTertiary),
                filled: true,
                fillColor: p.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                color: p.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              ElevatedButton.icon(
                key: Key(widget.sendKey),
                onPressed: _canSend ? _onSend : null,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              if (_inflightId != null) ...[
                const SizedBox(width: 16),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Response:',
            style: TextStyle(fontSize: 13, color: p.textTertiary),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _display.isEmpty ? '(no response yet)' : _display,
              key: Key(widget.responseKey),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: _displayColor() ??
                    (_display.isEmpty ? p.textPlaceholder : p.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DisplayKind { idle, pending, ok, businessError, timeout }
