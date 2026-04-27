import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:ota_monitor/controller/ota_collector.dart';

/// F009: OTA Manager Actor-service raw request/response UI.
///
/// Four cards (GetAppUpdateSettings, SetAppUpdateSettings, GetAppUpdateState,
/// SetAppUpdate). Each card has:
///   - an input form (at minimum an app_name field; SetSettings also has
///     an app_settings multiline field)
///   - a Send button
///   - a response area that shows `id / ret_code / body` on success,
///     a red ✕ on business-level error (ret_code != OK), a yellow ⚠ on
///     the 5-second UI timeout, and is disabled when the ROS topics are
///     not yet advertised.
///
/// Widget keys follow F020 widget-keys.md §5.
///
/// The UI 5-second timer is independent of the 30-second
/// [OtaCollector.requestTimeout] sweeper — the two serve different
/// purposes (user-facing feedback vs pending-request hygiene). See
/// docs/ux/ota-monitor-wireframe.md §4.
class ActorPage extends StatelessWidget {
  const ActorPage({
    super.key,
    required this.collector,
    this.selectedApp,
  });

  final OtaCollector collector;

  /// Shared notifier from OtaMonitorHomePage. When the user selects an app
  /// in the Apps tab, its name is pushed here and each _ActorCard pre-fills
  /// its app_name field automatically (gap 1).
  final ValueNotifier<String?>? selectedApp;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ActorCard(
            cardKey: 'card_actor_get_settings',
            title: 'GetAppUpdateSettings',
            fields: const [_FieldSpec('app_name', keyName: 'field_actor_get_settings_app_name')],
            sendKey: 'btn_actor_get_settings',
            responseKey: 'text_actor_get_settings_response',
            kind: OtaRequestKind.getSettings,
            collector: collector,
            selectedApp: selectedApp,
          ),
          const SizedBox(height: 16),
          _ActorCard(
            cardKey: 'card_actor_set_settings',
            title: 'SetAppUpdateSettings',
            fields: const [
              _FieldSpec('app_name', keyName: 'field_actor_set_settings_app_name'),
              _FieldSpec(
                'app_settings (JSON)',
                keyName: 'field_actor_set_settings_value',
                multiline: true,
              ),
            ],
            sendKey: 'btn_actor_set_settings',
            responseKey: 'text_actor_set_settings_response',
            kind: OtaRequestKind.setSettings,
            collector: collector,
            selectedApp: selectedApp,
          ),
          const SizedBox(height: 16),
          _ActorCard(
            cardKey: 'card_actor_get_state',
            title: 'GetAppUpdateState',
            fields: const [_FieldSpec('app_name', keyName: 'field_actor_get_state_app_name')],
            sendKey: 'btn_actor_get_state',
            responseKey: 'text_actor_get_state_response',
            kind: OtaRequestKind.getState,
            collector: collector,
            selectedApp: selectedApp,
          ),
          const SizedBox(height: 16),
          _ActorCard(
            cardKey: 'card_actor_set_update',
            title: 'SetAppUpdate',
            fields: const [_FieldSpec('app_name', keyName: 'field_actor_set_update_app_name')],
            sendKey: 'btn_actor_set_update',
            responseKey: 'text_actor_set_update_response',
            kind: OtaRequestKind.setUpdate,
            collector: collector,
            selectedApp: selectedApp,
          ),
        ],
      ),
    );
  }
}

class _FieldSpec {
  const _FieldSpec(this.label, {required this.keyName, this.multiline = false});
  final String label;
  final String keyName;
  final bool multiline;
}

class _ActorCard extends StatefulWidget {
  const _ActorCard({
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
  final List<_FieldSpec> fields;
  final String sendKey;
  final String responseKey;
  final OtaRequestKind kind;
  final OtaCollector collector;
  final ValueNotifier<String?>? selectedApp;

  @override
  State<_ActorCard> createState() => _ActorCardState();
}

class _ActorCardState extends State<_ActorCard> {
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
    // Gap 1: pre-fill app_name with currently selected app, then listen.
    final initial = widget.selectedApp?.value;
    if (initial != null && _controllers.isNotEmpty) {
      _controllers[0].text = initial;
    }
    widget.selectedApp?.addListener(_onSelectedAppChange);
  }

  void _onReadyChange() {
    if (mounted) setState(() {});
  }

  // Gap 1: when the user picks an app in the Apps tab, mirror it here.
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
      // F009 SHOULD #2 (rev 1): wireframe §4 mandates a leading ✕ glyph on
      // business-level errors so the affordance is consistent with ⚠ used
      // for timeouts. Color alone is insufficient (accessibility).
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
    // F009 SHOULD #1 (rev 1): wireframe §4 "미연결 → Send disabled".
    // The collector exposes isReady once _start() has finished
    // subscribing/advertising the Actor topics; before that, publish()
    // would silently fail with an errors-stream SnackBar and leave the
    // card's `_display` stuck on "Sending..." until the 5s timeout.
    if (!widget.collector.isReady) return false;
    // First field (app_name) must not be empty. Additional fields may be
    // empty (e.g. SetAppUpdateSettings with an empty app_settings is
    // accepted at the UI layer — the Manager decides.)
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

  Color? _displayColor(ThemeData theme) {
    switch (_displayKind) {
      case _DisplayKind.ok:
        return const Color(0xFF34D399);
      case _DisplayKind.businessError:
        return const Color(0xFFEF4444);
      case _DisplayKind.timeout:
        return const Color(0xFFF59E0B);
      case _DisplayKind.pending:
      case _DisplayKind.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: Key(widget.cardKey),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
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
                  backgroundColor: const Color(0xFF3B82F6),
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
          const Text(
            'Response:',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _display.isEmpty ? '(no response yet)' : _display,
              key: Key(widget.responseKey),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: _displayColor(theme) ??
                    (_display.isEmpty
                        ? const Color(0xFF6B7280)
                        : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DisplayKind { idle, pending, ok, businessError, timeout }
