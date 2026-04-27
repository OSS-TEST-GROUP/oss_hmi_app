import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_monitor/controller/ota_collector.dart';

class OtaViewPage extends StatefulWidget {
  const OtaViewPage({super.key, this.truncateLength = 100});

  final int truncateLength;

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
        backgroundColor: const Color(0xFFB45309),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCBD5E1),
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
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with live count — kept as a single Text for findability.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _iconBadge(Icons.apps, const Color(0xFF60A5FA)),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => Text(
                        'App List (${_otaCollector.appList.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )),
                ),
              ],
            ),
          ),
          // Refresh row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  key: const Key('btn_apps_refresh_list'),
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Manager 에서 App List 다시 조회',
                  onPressed: _onRefreshAppList,
                  color: const Color(0xFF60A5FA),
                ),
                Obx(() => Text(
                      'source: ${_otaCollector.appListSource}',
                      key: const Key('text_apps_list_source'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'monospace',
                      ),
                    )),
              ],
            ),
          ),
          const Divider(color: Color(0xFF374151), height: 1),
          // Scrollable list
          Expanded(
            child: Obx(() {
              if (_otaCollector.appList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '앱 없음\nRefresh 또는 테스트 앱 추가',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
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
          const Divider(color: Color(0xFF374151), height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _onAddTestApp,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('테스트 앱 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
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
    if (_selectedAppName == null) {
      return _Panel(
        child: Column(
          children: [
            _sectionHeader('App Details', Icons.info_outline, const Color(0xFF34D399)),
            const Expanded(
              child: Center(
                child: Text(
                  '← 앱을 선택하세요',
                  style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF)),
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
              const Color(0xFF34D399),
              trailing: Text(
                _selectedAppName!,
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(color: Color(0xFF374151), height: 1),
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
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_selectedAppName != null) {
                                _otaCollector.requestAppSettings(_selectedAppName!);
                              }
                            },
                            icon: const Icon(Icons.settings, size: 16),
                            label: const Text('Refresh Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_selectedAppName != null) {
                                _otaCollector.requestAppState(_selectedAppName!);
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh State'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _onRequestUpdate,
                        icon: const Icon(Icons.system_update_alt, size: 16),
                        label: const Text('Request Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      ),
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

  Widget _buildUpdateHistorySection() {
    return Obx(() {
      final history = _otaCollector.updateHistory;
      return _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'Update History',
              Icons.history,
              const Color(0xFFF59E0B),
              trailing: Text(
                '${history.length}',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
            const Divider(color: Color(0xFF374151), height: 1),
            Expanded(
              child: history.isEmpty
                  ? const Center(
                      child: Text(
                        '히스토리 없음',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: history.length,
                      itemBuilder: (_, i) => _HistoryItem(entry: history[i]),
                    ),
            ),
          ],
        ),
      );
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _iconBadge(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      );

  Widget _sectionHeader(String title, IconData icon, Color iconColor,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _iconBadge(icon, iconColor),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
    final display =
        value.length > _truncate ? '${value.substring(0, _truncate)}...' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                  fontFamily: 'monospace',
                ),
              ),
              if (onViewFull != null)
                GestureDetector(
                  onTap: onViewFull,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '전체 보기 →',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60A5FA),
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
    final color = status.contains('complete') || status == 'Synced'
        ? const Color(0xFF34D399)
        : status.contains('fail') || status.contains('error')
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    return Row(
      children: [
        const Text(
          'Status: ',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF374151), width: 0.5),
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
    final statusColor = status.contains('complete') || status == 'Synced'
        ? const Color(0xFF34D399)
        : status.contains('fail') || status.contains('error')
            ? const Color(0xFFEF4444)
            : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
              : const Color(0xFF374151).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.app_settings_alt,
              color: isSelected
                  ? const Color(0xFF60A5FA)
                  : const Color(0xFF9CA3AF),
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
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
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
              const Icon(Icons.chevron_right,
                  color: Color(0xFF60A5FA), size: 20),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final timestamp = entry['timestamp'] as String;
    final appName = entry['app_name'] as String;
    final message = entry['message'] as String;
    final retCode = entry['ret_code'] as int?;

    final icon = retCode == 1
        ? Icons.check_circle
        : retCode == 2
            ? Icons.error
            : Icons.info;
    final color = retCode == 1
        ? const Color(0xFF34D399)
        : retCode == 2
            ? const Color(0xFFEF4444)
            : const Color(0xFF60A5FA);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$appName — $message',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                Text(
                  timestamp.length >= 19
                      ? timestamp.substring(0, 19)
                      : timestamp,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
