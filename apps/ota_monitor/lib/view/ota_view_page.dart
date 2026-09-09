import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_monitor/controller/client_service_controller.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/theme/app_palette.dart';
import 'package:ota_monitor/view/client_page.dart';
import 'package:ota_monitor/view/widgets/actor_card.dart';

class OtaViewPage extends StatefulWidget {
  const OtaViewPage({
    super.key,
    this.truncateLength = 100,
    this.selectedApp,
    this.clientController,
  });

  final int truncateLength;

  /// Shared notifier so the Actor cards on the right can pre-fill
  /// app_name when an app is selected on the left list. Optional —
  /// tests omit it.
  final ValueNotifier<String?>? selectedApp;

  /// Wired up by OtaMonitorHomePage once Ros is available so the bottom
  /// half of the left panel can render the Client section
  /// (New Client Registration / Manager Status / App Update Status). When
  /// null, the bottom half shows a "Ros connecting…" placeholder.
  final ClientServiceController? clientController;

  @override
  State<OtaViewPage> createState() => _OtaViewPageState();
}

class _OtaViewPageState extends State<OtaViewPage> {
  late OtaCollector _otaCollector;
  String? _selectedAppName;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _startConnect();
    _errorSub = _otaCollector.errors.listen(_showErrorSnack);
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: palette.errorBg,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startConnect() {
    if (Get.isRegistered<OtaCollector>()) {
      _otaCollector = Get.find<OtaCollector>();
    } else {
      _otaCollector = Get.put(OtaCollector());
    }
  }

  void _onAppSelected(String appName) {
    setState(() => _selectedAppName = appName);
    widget.selectedApp?.value = appName;
    _otaCollector.requestAppSettings(appName);
    _otaCollector.requestAppState(appName);
  }

  Future<void> _onRefreshAppList() async {
    final beforeGen = _otaCollector.appListGeneration.value;
    _otaCollector.requestAppList();
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    if (_otaCollector.appListGeneration.value == beforeGen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('앱 목록 조회 시간 초과 — 로컬 캐시 사용'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ─── Left panel: scrollable app list ──────────────────────────────────────

  Widget _buildAppListPanel() {
    final p = palette;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _iconBadge(Icons.apps, p.accentBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => Text(
                        'App List (${_otaCollector.appList.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: p.textPrimary,
                        ),
                      )),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('btn_apps_refresh_list'),
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Manager 에서 App List 다시 조회',
                  onPressed: _onRefreshAppList,
                  color: p.accentBlue,
                ),
                Obx(() => Text(
                      'source: ${_otaCollector.appListSource}',
                      key: const Key('text_apps_list_source'),
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textTertiary,
                        fontFamily: 'monospace',
                      ),
                    )),
              ],
            ),
          ),
          Divider(color: p.divider, height: 1),
          Expanded(
            child: Obx(() {
              // Touch the reactive map so Obx rebuilds on client-name
              // changes too, not just on appList replacement.
              final _ = _otaCollector.clientNamesById.length;
              if (_otaCollector.appList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '앱 없음\nRefresh 로 다시 조회하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              // Group apps by owner client_id (apps with no owner are
              // bucketed under -1 to stay visible — happens until the
              // first GetAppListResponse arrives or for initialApps
              // seeded locally).
              final byOwner = <int, List<Map<String, dynamic>>>{};
              for (final app in _otaCollector.appList) {
                final ownerId = (app['ownerClientId'] as int?) ?? -1;
                byOwner.putIfAbsent(ownerId, () => []).add(app);
              }
              final ownerIds = byOwner.keys.toList()..sort();

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: ownerIds.length,
                itemBuilder: (_, i) {
                  final ownerId = ownerIds[i];
                  final clientName =
                      _otaCollector.clientNamesById[ownerId];
                  final apps = byOwner[ownerId]!;
                  return _ClientGroupTile(
                    clientId: ownerId,
                    clientName: clientName,
                    apps: apps,
                    selectedAppName: _selectedAppName,
                    onAppTap: _onAppSelected,
                    onDeleteClient: ownerId >= 0
                        ? () => _confirmDeleteClient(ownerId, clientName)
                        : null,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteClient(int clientId, String? clientName) async {
    final p = palette;
    final label = clientName != null && clientName.isNotEmpty
        ? 'Client #$clientId — $clientName'
        : 'Client #$clientId';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Delete client',
            style: TextStyle(color: p.textPrimary, fontSize: 18)),
        content: Text(
          '$label 의 등록 및 모든 앱을 삭제할까요?',
          style: TextStyle(color: p.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.error),
            child: const Text('삭제'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok == true) {
      _otaCollector.deleteClient(clientId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label 삭제 요청됨')),
        );
      }
    }
  }

  // ─── Right panel: 4 Actor cards (inline, no modal) ────────────────────────

  Widget _buildActorPanel() {
    final p = palette;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader('Actor API Call', Icons.api, p.accentBlue),
          Divider(color: p.divider, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  ActorCard(
                    cardKey: 'card_actor_get_settings',
                    title: 'GetAppUpdateSettings',
                    fields: const [
                      ActorCardField('app_name', keyName: 'field_actor_get_settings_app_name'),
                    ],
                    sendKey: 'btn_actor_get_settings',
                    responseKey: 'text_actor_get_settings_response',
                    kind: OtaRequestKind.getSettings,
                    collector: _otaCollector,
                    selectedApp: widget.selectedApp,
                  ),
                  const SizedBox(height: 16),
                  ActorCard(
                    cardKey: 'card_actor_set_settings',
                    title: 'SetAppUpdateSettings',
                    fields: const [
                      ActorCardField('app_name', keyName: 'field_actor_set_settings_app_name'),
                      ActorCardField(
                        'app_settings (JSON)',
                        keyName: 'field_actor_set_settings_value',
                        multiline: true,
                      ),
                    ],
                    sendKey: 'btn_actor_set_settings',
                    responseKey: 'text_actor_set_settings_response',
                    kind: OtaRequestKind.setSettings,
                    collector: _otaCollector,
                    selectedApp: widget.selectedApp,
                  ),
                  const SizedBox(height: 16),
                  ActorCard(
                    cardKey: 'card_actor_get_state',
                    title: 'GetAppUpdateState',
                    fields: const [
                      ActorCardField('app_name', keyName: 'field_actor_get_state_app_name'),
                    ],
                    sendKey: 'btn_actor_get_state',
                    responseKey: 'text_actor_get_state_response',
                    kind: OtaRequestKind.getState,
                    collector: _otaCollector,
                    selectedApp: widget.selectedApp,
                  ),
                  const SizedBox(height: 16),
                  ActorCard(
                    cardKey: 'card_actor_set_update',
                    title: 'SetAppUpdate',
                    fields: const [
                      ActorCardField('app_name', keyName: 'field_actor_set_update_app_name'),
                    ],
                    sendKey: 'btn_actor_set_update',
                    responseKey: 'text_actor_set_update_response',
                    kind: OtaRequestKind.setUpdate,
                    collector: _otaCollector,
                    selectedApp: widget.selectedApp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _iconBadge(IconData icon, Color color) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  /// Standard panel header used by Actor and Client sections. Matches
  /// the App List header's styling (icon badge + title) so the three
  /// panels read as siblings.
  Widget _panelHeader(String title, IconData icon, Color iconColor) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _iconBadge(icon, iconColor),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Left panel bottom: Client section ────────────────────────────────────

  Widget _buildClientSection() {
    final p = palette;
    final c = widget.clientController;
    final Widget body = c == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Ros connecting…\nClient 정보 대기 중',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textTertiary, fontSize: 14),
              ),
            ),
          )
        : ClientPage(controller: c);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader('Client Interaction', Icons.swap_horiz, p.accentBlue),
          Divider(color: p.divider, height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildAppListPanel()),
                const SizedBox(height: 16),
                Expanded(child: _buildClientSection()),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: _buildActorPanel()),
        ],
      ),
    );
  }
}

// ─── Private sub-widgets ────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.divider, width: 1),
      ),
      child: child,
    );
  }
}

/// Expandable group of apps owned by a single client. Renders the
/// header as "Client #<id> — <name>" plus a trash icon (when the
/// client_id is valid) that asks the parent to confirm + publish
/// DeleteOtaClientRegistration.
class _ClientGroupTile extends StatelessWidget {
  const _ClientGroupTile({
    required this.clientId,
    required this.clientName,
    required this.apps,
    required this.selectedAppName,
    required this.onAppTap,
    this.onDeleteClient,
  });

  final int clientId;
  final String? clientName;
  final List<Map<String, dynamic>> apps;
  final String? selectedAppName;
  final void Function(String appName) onAppTap;
  final VoidCallback? onDeleteClient;

  String get _headerLabel {
    if (clientId < 0) return 'Unassigned';
    final name = clientName;
    return (name != null && name.isNotEmpty)
        ? 'Client #$clientId — $name'
        : 'Client #$clientId';
  }

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Container(
        key: Key('client_group_$clientId'),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: p.surfaceAlt.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        // flutter 3.41.8: ListTile(ExpansionTile 헤더)이 배경색 있는 상위(Container
        // decoration) 위에 있으면 "ink splash may be invisible" assertion 이 뜬다.
        // 투명 Material 로 감싸 ListTile 이 자신의 Material 조상을 갖게 한다(외형 불변).
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
          title: Text(
            _headerLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: p.textPrimary,
            ),
          ),
          subtitle: Text(
            '${apps.length} app${apps.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11, color: p.textTertiary),
          ),
          trailing: onDeleteClient != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('btn_delete_client_$clientId'),
                      icon: Icon(Icons.delete_outline, size: 18, color: p.error),
                      tooltip: 'Delete this client',
                      onPressed: onDeleteClient,
                    ),
                    Icon(Icons.expand_more, color: p.textTertiary, size: 20),
                  ],
                )
              : null,
          children: [
            for (final app in apps)
              _AppListTile(
                appName: app['name'] as String,
                status: app['status'] as String? ?? 'Unknown',
                isSelected: app['name'] == selectedAppName,
                onTap: () => onAppTap(app['name'] as String),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

class _AppListTile extends StatelessWidget {
  const _AppListTile({
    required this.appName,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final String appName;
  final String status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final statusColor = status.contains('complete') || status == 'Synced'
        ? p.success
        : status.contains('fail') || status.contains('error')
            ? p.error
            : p.textTertiary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? p.selectionBg : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? p.selectionBorder : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.app_settings_alt,
              color: isSelected ? p.primary : p.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.chevron_right, color: p.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
