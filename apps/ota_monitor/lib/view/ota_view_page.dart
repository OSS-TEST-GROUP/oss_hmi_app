import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/theme/app_palette.dart';

class OtaViewPage extends StatefulWidget {
  const OtaViewPage({
    super.key,
    this.truncateLength = 100,
    this.selectedApp,
    this.clientIdNotifier,
  });

  final int truncateLength;

  /// Shared notifier so Actor modal can pre-fill app_name when an app is
  /// selected here. Optional — tests omit it.
  final ValueNotifier<String?>? selectedApp;

  /// Our own client_id once Client modal registers. Update History uses
  /// this to highlight "mine vs others" entries. Optional.
  final ValueNotifier<int?>? clientIdNotifier;

  @override
  State<OtaViewPage> createState() => _OtaViewPageState();
}

class _OtaViewPageState extends State<OtaViewPage> {
  late OtaCollector _otaCollector;
  String? _selectedAppName;
  StreamSubscription<String>? _errorSub;

  int get _truncate => widget.truncateLength;

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

  void _onAddTestApp() {
    showDialog(
      context: context,
      builder: (ctx) {
        String appName = '';
        return AlertDialog(
          title: const Text('테스트 앱 추가'),
          content: TextField(
            decoration: const InputDecoration(hintText: '앱 이름 입력'),
            onChanged: (v) => appName = v,
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('추가'),
              onPressed: () {
                if (appName.isNotEmpty) {
                  _otaCollector.requestAppSettings(appName);
                  _otaCollector.requestAppState(appName);
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _onSetSettings() {
    if (_selectedAppName == null) return;
    final p = palette;
    final current =
        _otaCollector.topicData['${_selectedAppName}_settings'] as String? ?? '';
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(
          'Set Settings: $_selectedAppName',
          style: TextStyle(color: p.textPrimary, fontSize: 18),
        ),
        content: SizedBox(
          width: 480,
          child: TextField(
            key: const Key('field_set_settings_json'),
            controller: controller,
            maxLines: 8,
            minLines: 4,
            style: TextStyle(
              color: p.textPrimary,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: '{"interval": 5, ...}',
              hintStyle: TextStyle(color: p.textPlaceholder),
              filled: true,
              fillColor: p.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton.icon(
            key: const Key('btn_set_settings_apply'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Apply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () {
              _otaCollector.setAppSettings(_selectedAppName!, controller.text);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('SetSettings 요청됨: $_selectedAppName')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onRequestUpdate() {
    if (_selectedAppName == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('확인'),
        content: Text('$_selectedAppName 앱의 업데이트를 요청하시겠습니까?'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('확인'),
            onPressed: () {
              _otaCollector.requestUpdate(_selectedAppName!);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$_selectedAppName 업데이트 요청됨')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFullTextDialog(String title, String content) {
    final p = palette;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(title, style: TextStyle(color: p.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 14,
                color: p.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('닫기'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
                      '앱 없음\nRefresh 또는 테스트 앱 추가',
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
          Divider(color: p.divider, height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onAddTestApp,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('테스트 앱 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Right panel: detail + history ────────────────────────────────────────

  Widget _buildDetailPanel() {
    return Column(
      children: [
        Expanded(flex: 3, child: _buildAppDetailsSection()),
        const SizedBox(height: 12),
        Expanded(flex: 2, child: _buildUpdateHistorySection()),
      ],
    );
  }

  Widget _buildAppDetailsSection() {
    final p = palette;
    if (_selectedAppName == null) {
      return _Panel(
        child: Column(
          children: [
            _sectionHeader('App Details', Icons.info_outline, p.success),
            Expanded(
              child: Center(
                child: Text(
                  '← 앱을 선택하세요',
                  style: TextStyle(fontSize: 16, color: p.textTertiary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() {
      final settings =
          _otaCollector.topicData['${_selectedAppName}_settings'] as String? ??
              'Loading...';
      final state =
          _otaCollector.topicData['${_selectedAppName}_state'] as String? ??
              'Loading...';
      final status =
          _otaCollector.topicData['${_selectedAppName}_status'] as String? ??
              'Unknown';

      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'App Details',
              Icons.info_outline,
              p.success,
              trailing: Text(
                _selectedAppName!,
                style: TextStyle(
                  color: p.accentBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Divider(color: p.divider, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailField('App Name', _selectedAppName!),
                    const SizedBox(height: 10),
                    _statusBadge(status),
                    const SizedBox(height: 10),
                    _detailField(
                      'Settings',
                      settings,
                      onViewFull: settings.length > _truncate
                          ? () => _showFullTextDialog(
                              'Settings - $_selectedAppName', settings)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _detailField(
                      'State Info',
                      state,
                      onViewFull: state.length > _truncate
                          ? () => _showFullTextDialog(
                              'State Info - $_selectedAppName', state)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            keyName: 'btn_app_get_settings',
                            label: 'Get Settings',
                            icon: Icons.download,
                            color: p.actionGet,
                            onPressed: () {
                              if (_selectedAppName != null) {
                                _otaCollector
                                    .requestAppSettings(_selectedAppName!);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionButton(
                            keyName: 'btn_app_set_settings',
                            label: 'Set Settings',
                            icon: Icons.upload,
                            color: p.actionSet,
                            onPressed: _onSetSettings,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            keyName: 'btn_app_get_state',
                            label: 'Get State',
                            icon: Icons.refresh,
                            color: p.actionRefresh,
                            onPressed: () {
                              if (_selectedAppName != null) {
                                _otaCollector
                                    .requestAppState(_selectedAppName!);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionButton(
                            keyName: 'btn_app_request_update',
                            label: 'Request Update',
                            icon: Icons.system_update_alt,
                            color: p.actionDanger,
                            onPressed: _onRequestUpdate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _actionButton({
    required String keyName,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      key: Key(keyName),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: palette.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _buildUpdateHistorySection() {
    final p = palette;
    return Obx(() {
      final history = _otaCollector.updateHistory;
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'Update History',
              Icons.history,
              p.warning,
              trailing: Text(
                '${history.length}',
                style: TextStyle(color: p.textTertiary, fontSize: 14),
              ),
            ),
            Divider(color: p.divider, height: 1),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        '히스토리 없음',
                        style: TextStyle(
                          fontSize: 14,
                          color: p.textTertiary,
                        ),
                      ),
                    )
                  : ValueListenableBuilder<int?>(
                      valueListenable:
                          widget.clientIdNotifier ?? ValueNotifier<int?>(null),
                      builder: (_, myId, __) => ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: history.length,
                        itemBuilder: (_, i) => _HistoryItem(
                          entry: history[i],
                          myClientId: myId,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
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

  Widget _sectionHeader(String title, IconData icon, Color iconColor,
      {Widget? trailing}) {
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
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _detailField(String label, String value, {VoidCallback? onViewFull}) {
    final p = palette;
    final display =
        value.length > _truncate ? '${value.substring(0, _truncate)}...' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: p.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: TextStyle(
                  fontSize: 13,
                  color: p.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              if (onViewFull != null)
                GestureDetector(
                  onTap: onViewFull,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '전체 보기 →',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.accentBlue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final p = palette;
    final color = status.contains('complete') || status == 'Synced'
        ? p.success
        : status.contains('fail') || status.contains('error')
            ? p.error
            : p.warning;
    return Row(
      children: [
        Text(
          'Status: ',
          style: TextStyle(fontSize: 12, color: p.textTertiary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 1, child: _buildAppListPanel()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildDetailPanel()),
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

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry, this.myClientId});

  final Map<String, dynamic> entry;
  final int? myClientId;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final timestamp = entry['timestamp'] as String;
    final appName = entry['app_name'] as String;
    final message = entry['message'] as String;
    final retCode = entry['ret_code'] as int?;
    final entryClientId = entry['client_id'] as int?;
    final isMine =
        myClientId != null && entryClientId != null && entryClientId == myClientId;

    final icon = retCode == 1
        ? Icons.check_circle
        : retCode == 2
            ? Icons.error
            : Icons.info;
    final iconColor = retCode == 1
        ? p.success
        : retCode == 2
            ? p.error
            : p.accentBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMine ? p.selectionBg : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isMine ? p.selectionBorder : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMine ? '▣' : '□',
            style: TextStyle(
              fontSize: 14,
              color: isMine ? p.primary : p.textPlaceholder,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entryClientId != null
                      ? '$appName — $message  (cid=$entryClientId)'
                      : '$appName — $message',
                  style: TextStyle(
                    fontSize: 14,
                    color: p.textPrimary,
                    fontWeight:
                        isMine ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Text(
                  timestamp.length >= 19
                      ? timestamp.substring(0, 19)
                      : timestamp,
                  style: TextStyle(fontSize: 12, color: p.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
