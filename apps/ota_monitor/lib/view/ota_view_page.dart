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
  /// (Self Registration / Manager Status / App Update Status). When
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
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _otaCollector.appList.length,
                itemBuilder: (_, i) {
                  final app = _otaCollector.appList[i];
                  final name = app['name'] as String;
                  final status = app['status'] as String? ?? 'Unknown';
                  return _AppListTile(
                    appName: name,
                    status: status,
                    isSelected: name == _selectedAppName,
                    onTap: () => _onAppSelected(name),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Right panel: 4 Actor cards (inline, no modal) ────────────────────────

  Widget _buildActorPanel() {
    return SingleChildScrollView(
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

  // ─── Left panel bottom: Client section ────────────────────────────────────

  Widget _buildClientSection() {
    final p = palette;
    final c = widget.clientController;
    if (c == null) {
      return _Panel(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Ros connecting…\nClient 정보 대기 중',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textTertiary, fontSize: 14),
            ),
          ),
        ),
      );
    }
    return _Panel(child: ClientPage(controller: c));
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
