import 'package:flutter/material.dart';

import 'package:ota_monitor/controller/client_service_controller.dart';
import 'package:ota_monitor/theme/app_palette.dart';

/// F021 — Client tab. Three cards:
///   1. New Client Registration (card_client_register)
///        SetOtaClientRegistration → client_id 표시
///   2. Manager Status (card_client_manager_status)
///        NotifyOtaManagerReady 수신 / heartbeat seq+ts
///   3. App Update Status (card_client_app_status)
///        NotifyAppUpdateStatus 수신 리스트
///
/// All widget keys follow F020 widget-keys.md §6.
class ClientPage extends StatefulWidget {
  const ClientPage({super.key, required this.controller});

  final ClientServiceController controller;

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  late final TextEditingController _nameField;
  late final TextEditingController _appListField;

  @override
  void initState() {
    super.initState();
    _nameField = TextEditingController(text: 'ota_monitor');
    _appListField = TextEditingController(text: 'app_a, app_b');
    widget.controller.addListener(_onModelChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onModelChange);
    _nameField.dispose();
    _appListField.dispose();
    super.dispose();
  }

  void _onModelChange() {
    if (mounted) setState(() {});
  }

  Future<void> _onRegister() async {
    final name = _nameField.text.trim();
    if (name.isEmpty) return;
    final apps = _appListField.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await widget.controller.register(name, apps);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRegistrationCard(c),
          const SizedBox(height: 16),
          _buildManagerStatusCard(c),
          const SizedBox(height: 16),
          _buildAppStatusCard(c),
        ],
      ),
    );
  }

  Widget _card({required Key key, required Widget child}) {
    final p = palette;
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: child,
    );
  }

  TextStyle _titleStyle() => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: palette.textPrimary,
      );

  Widget _buildRegistrationCard(ClientServiceController c) {
    final p = palette;
    return _card(
      key: const Key('card_client_register'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Client Registration', style: _titleStyle()),
          const SizedBox(height: 12),
          _input(
            label: 'client_name',
            keyName: 'field_client_name',
            controller: _nameField,
          ),
          const SizedBox(height: 12),
          _input(
            label: 'app_list (comma-separated)',
            keyName: 'field_client_app_list',
            controller: _appListField,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                key: const Key('btn_client_register'),
                onPressed: _onRegister,
                icon: const Icon(Icons.app_registration, size: 18),
                label: const Text('Register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                c.clientId == null
                    ? 'client_id: (not registered)'
                    : 'client_id: ${c.clientId}',
                key: const Key('text_client_id'),
                style: TextStyle(
                  color: p.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagerStatusCard(ClientServiceController c) {
    final p = palette;
    final seq = c.heartbeatSeq;
    final tsMs = c.heartbeatTimestampMs;
    final tsLabel = tsMs == null
        ? '—'
        : _fmtTs(DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: false));
    final stale = c.isHeartbeatStale;
    return _card(
      key: const Key('card_client_manager_status'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manager Status', style: _titleStyle()),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Ready: ',
                style: TextStyle(color: p.textSecondary),
              ),
              Icon(
                Icons.circle,
                key: const Key('icon_manager_ready'),
                size: 14,
                color: c.managerReady ? p.success : p.textPlaceholder,
              ),
              const SizedBox(width: 8),
              Text(
                c.managerReady ? 'received' : 'waiting',
                style: TextStyle(
                  fontSize: 13,
                  color: p.textSecondary,
                ),
              ),
              if (stale && seq != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.timer,
                  key: const Key('icon_heartbeat_stale'),
                  size: 16,
                  color: p.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'stale',
                  style: TextStyle(fontSize: 12, color: p.warning),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'seq=${seq ?? '—'}',
            key: const Key('text_heartbeat_seq'),
            style: TextStyle(
              fontSize: 13,
              color: stale ? p.warning : p.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'ts=$tsLabel',
            key: const Key('text_heartbeat_timestamp'),
            style: TextStyle(
              fontSize: 13,
              color: stale ? p.warning : p.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// Compact display of a heartbeat timestamp. Mirrors the wireframe's
  /// HH:mm:ss.SSS expectation; uses the local clock so the operator sees
  /// "when did the Manager send this *in monitor time*".
  String _fmtTs(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }

  Widget _buildAppStatusCard(ClientServiceController c) {
    final p = palette;
    final myId = c.clientId;
    return _card(
      key: const Key('card_client_app_status'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App Update Status (${c.statuses.length})', style: _titleStyle()),
          const SizedBox(height: 12),
          if (c.statuses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'no NotifyAppUpdateStatus messages yet',
                  style: TextStyle(color: p.textTertiary),
                ),
              ),
            )
          else
            ListView.builder(
              key: const Key('list_app_update_status'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.statuses.length,
              itemBuilder: (context, i) {
                final m = c.statuses[i];
                final cid = (m['client_id'] as num?)?.toInt();
                final isMine = (myId != null && cid == myId);
                return Container(
                  key: Key('tile_app_update_status_$i'),
                  padding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 8),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: isMine ? p.selectionBg : p.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isMine ? p.selectionBorder : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isMine ? '▣' : '□',
                        style: TextStyle(
                          color: isMine ? p.primary : p.textPlaceholder,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'client_id=${cid ?? '?'}  '
                          'app=${m['app_name']}  '
                          'status=${m['status']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: p.textPrimary,
                            fontWeight:
                                isMine ? FontWeight.w500 : FontWeight.normal,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _input({
    required String label,
    required String keyName,
    required TextEditingController controller,
  }) {
    final p = palette;
    return TextField(
      key: Key(keyName),
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
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
    );
  }
}
