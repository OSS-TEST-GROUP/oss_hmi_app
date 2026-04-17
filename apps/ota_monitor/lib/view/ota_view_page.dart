import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ota_monitor/controller/ota_collector.dart';
import 'package:ota_monitor/widget/data_view_widget.dart';
import 'package:ota_monitor/widget/key_value_item.dart';

class OtaViewPage extends StatefulWidget {
  const OtaViewPage({super.key, this.truncateLength = 100});

  /// Character count at which Settings/State values are truncated to
  /// "…" with a "전체 보기" affordance. Configurable via AppConfig (F005).
  final int truncateLength;

  @override
  State<OtaViewPage> createState() => _OtaViewPageState();
}

class _OtaViewPageState extends State<OtaViewPage> {
  late OtaCollector _otaCollector;
  String? _selectedAppName;

  int get _truncate => widget.truncateLength;

  final Map<String, bool> _expandedSections = {
    'appList': true,
    'appDetail': true,
    'updateHistory': true,
  };

  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _startConnect();
    // F007: surface publish errors as SnackBars.
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

  void _toggleSection(String key) {
    setState(() {
      _expandedSections[key] = !(_expandedSections[key] ?? false);
    });
  }

  void _onAppSelected(String appName) {
    setState(() {
      _selectedAppName = appName;
    });
    // 앱 선택 시 상세 정보 요청
    _otaCollector.requestAppSettings(appName);
    _otaCollector.requestAppState(appName);
  }

  void _onRefreshSettings() {
    if (_selectedAppName != null) {
      _otaCollector.requestAppSettings(_selectedAppName!);
    }
  }

  void _onRefreshState() {
    if (_selectedAppName != null) {
      _otaCollector.requestAppState(_selectedAppName!);
    }
  }

  void _onRequestUpdate() {
    if (_selectedAppName != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('확인'),
          content: Text('$_selectedAppName 앱의 업데이트를 요청하시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                _otaCollector.requestUpdate(_selectedAppName!);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$_selectedAppName 업데이트 요청됨')),
                );
              },
            ),
          ],
        ),
      );
    }
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

  void _onAddTestApp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String appName = '';
        return AlertDialog(
          title: const Text('테스트 앱 추가'),
          content: TextField(
            decoration: const InputDecoration(hintText: '앱 이름 입력'),
            onChanged: (value) => appName = value,
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('추가'),
              onPressed: () {
                if (appName.isNotEmpty) {
                  _otaCollector.requestAppSettings(appName);
                  _otaCollector.requestAppState(appName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 앱 목록
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Obx(() => DataViewWidget(
                      title: 'App List (${_otaCollector.appList.length})',
                      icon: Icons.apps,
                      iconColor: const Color(0xFF60A5FA),
                      isExpanded: _expandedSections['appList'] ?? true,
                      onTap: () => _toggleSection('appList'),
                      children: [
                        ..._otaCollector.appList.map((app) {
                          final appName = app['name'] as String;
                          final status = app['status'] as String? ?? 'Unknown';
                          final isSelected = appName == _selectedAppName;

                          return InkWell(
                            onTap: () => _onAppSelected(appName),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                                    : const Color(0xFF374151).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6)
                                      : Colors.transparent,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          status,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _onAddTestApp,
                          icon: const Icon(Icons.add),
                          label: const Text('테스트 앱 추가'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // 오른쪽: 앱 상세 정보 + 업데이트 히스토리
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // 앱 상세 정보
                if (_selectedAppName == null)
                  DataViewWidget(
                    title: 'App Details',
                    icon: Icons.info_outline,
                    iconColor: const Color(0xFF34D399),
                    isExpanded: _expandedSections['appDetail'] ?? true,
                    onTap: () => _toggleSection('appDetail'),
                    children: const [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '앱을 선택하세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Obx(() {
                    final settings =
                        _otaCollector.topicData['${_selectedAppName}_settings'] as String? ?? 'Loading...';
                    final state =
                        _otaCollector.topicData['${_selectedAppName}_state'] as String? ?? 'Loading...';
                    final status =
                        _otaCollector.topicData['${_selectedAppName}_status'] as String? ?? 'Unknown';

                    return DataViewWidget(
                      title: 'App Details: $_selectedAppName',
                      icon: Icons.info_outline,
                      iconColor: const Color(0xFF34D399),
                      isExpanded: _expandedSections['appDetail'] ?? true,
                      onTap: () => _toggleSection('appDetail'),
                      children: [
                        KeyValueItem(
                          label: 'App Name',
                          value: _selectedAppName!,
                        ),
                        KeyValueItem(
                          label: 'Status',
                          value: status,
                          status: status == 'Synced' || status.contains('complete')
                              ? StatusType.good
                              : status.contains('fail') || status.contains('error')
                                  ? StatusType.error
                                  : StatusType.warning,
                        ),
                        KeyValueItem(
                          label: 'Settings',
                          value: settings.length > _truncate
                              ? '${settings.substring(0, _truncate)}...'
                              : settings,
                          subtitle:
                              settings.length > _truncate ? '전체 보기 →' : null,
                          onSubtitleTap: settings.length > _truncate
                              ? () => _showFullTextDialog(
                                  'Settings - $_selectedAppName', settings)
                              : null,
                        ),
                        KeyValueItem(
                          label: 'State Info',
                          value: state.length > _truncate
                              ? '${state.substring(0, _truncate)}...'
                              : state,
                          subtitle:
                              state.length > _truncate ? '전체 보기 →' : null,
                          onSubtitleTap: state.length > _truncate
                              ? () => _showFullTextDialog(
                                  'State Info - $_selectedAppName', state)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _onRefreshSettings,
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Refresh Settings'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _onRefreshState,
                                icon: const Icon(Icons.refresh, size: 18),
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
                            icon: const Icon(Icons.system_update_alt),
                            label: const Text('Request Update'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                const SizedBox(height: 24),
                // 업데이트 히스토리
                Expanded(
                  child: Obx(() => DataViewWidget(
                        title: 'Update History (${_otaCollector.updateHistory.length})',
                        icon: Icons.history,
                        iconColor: const Color(0xFFF59E0B),
                        isExpanded: _expandedSections['updateHistory'] ?? true,
                        onTap: () => _toggleSection('updateHistory'),
                        children: [
                          if (_otaCollector.updateHistory.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  '히스토리 없음',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._otaCollector.updateHistory.map((item) {
                              final timestamp = item['timestamp'] as String;
                              final appName = item['app_name'] as String;
                              final message = item['message'] as String;
                              final retCode = item['ret_code'] as int?;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      retCode == 1
                                          ? Icons.check_circle
                                          : retCode == 2
                                              ? Icons.error
                                              : Icons.info,
                                      color: retCode == 1
                                          ? const Color(0xFF34D399)
                                          : retCode == 2
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF60A5FA),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$appName - $message',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            timestamp.substring(0, 19),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
