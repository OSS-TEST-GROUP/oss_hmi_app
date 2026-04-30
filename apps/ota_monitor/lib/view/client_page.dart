import 'package:flutter/material.dart';

import 'package:ota_monitor/controller/client_service_controller.dart';

/// F021 — Client tab. Three cards:
///   1. Self Registration (card_client_register)
///        SetOtaClientRegistration → client_id 표시
///   2. Manager Status (card_client_manager_status)
///        NotifyOtaManagerReady 수신 / heartbeat seq+ts
///   3. App Update Status (card_client_app_status)
///        NotifyAppUpdateStatus 수신 리스트
///
/// All widget keys follow F020 widget-keys.md §6.
///
/// The page is a [StatefulWidget] that listens to the controller's
/// ChangeNotifier so test code can verify reactive updates without
/// pumping a real Ros connection (see ClientServiceController.injectXxx).
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

  // ── card 1 ───────────────────────────────────────────────────────────
  Widget _buildRegistrationCard(ClientServiceController c) {
    return Container(
      key: const Key('card_client_register'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Self Registration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
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
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                c.clientId == null
                    ? 'client_id: (not registered)'
                    : 'client_id: ${c.clientId}',
                key: const Key('text_client_id'),
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── card 2 ───────────────────────────────────────────────────────────
  Widget _buildManagerStatusCard(ClientServiceController c) {
    return Container(
      key: const Key('card_client_manager_status'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manager Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Ready: ',
                style: TextStyle(color: Color(0xFFCBD5E1)),
              ),
              Icon(
                Icons.circle,
                key: const Key('icon_manager_ready'),
                size: 14,
                color: c.managerReady
                    ? const Color(0xFF34D399)   // green when ready
                    : const Color(0xFF6B7280),  // grey otherwise
              ),
              const SizedBox(width: 8),
              Text(
                c.managerReady ? 'received' : 'waiting',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Heartbeat fields are owned by the smoke/error scenarios
          // (F011 / F019); the Client tab just exposes the keys so
          // those tests can find them, even though the values aren't
          // wired here yet (see also docs/ux/widget-keys.md §6-2).
          const Text(
            'seq=—',
            key: Key('text_heartbeat_seq'),
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const Text(
            'ts=—',
            key: Key('text_heartbeat_timestamp'),
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 0, height: 0,
              child: Icon(
                Icons.timer,
                key: Key('icon_heartbeat_stale'),
                size: 0,        // hidden; F019 will style it on stale
                color: Color(0x00000000),
              )),
        ],
      ),
    );
  }

  // ── card 3 ───────────────────────────────────────────────────────────
  Widget _buildAppStatusCard(ClientServiceController c) {
    final myId = c.clientId;
    return Container(
      key: const Key('card_client_app_status'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Update Status (${c.statuses.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (c.statuses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'no NotifyAppUpdateStatus messages yet',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
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
                    color: isMine
                        ? const Color(0xFF1E40AF).withValues(alpha: 0.4)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isMine ? '▣' : '□',
                        style: TextStyle(
                          color: isMine
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.bold,
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
                            color: Colors.white,
                            fontWeight:
                                isMine ? FontWeight.bold : FontWeight.normal,
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

  // ── small helper ─────────────────────────────────────────────────────
  Widget _input({
    required String label,
    required String keyName,
    required TextEditingController controller,
  }) {
    return TextField(
      key: Key(keyName),
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
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
    );
  }
}
