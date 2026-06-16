// coverage:ignore-file

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adsw_monitor/controller/mw_collector.dart';
import 'package:adsw_monitor/theme/adsw_palette.dart';
import 'package:adsw_monitor/widget/data_view_widget.dart';
import 'package:adsw_monitor/widget/key_value_item.dart';
//import 'package:adsw_monitor/data/mw_data.dart';
import 'package:roslibdart/roslibdart.dart';

class MwViewPage extends StatefulWidget {
  const MwViewPage({super.key});

  @override
  MwViewPageState createState() => MwViewPageState();
}

class MwViewPageState extends State<MwViewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final MwCollector _mwCollector;

  final Map<String, bool> _expandedSections = {
    'notification': false,
    'security': false,
    'diagnostic': false,
  };

  Worker? _securityWorker;

  final List<String> _securityQueue = [];
  bool _showingSecurityDialog = false;

  @override
  void initState() {
    super.initState();
    _startConnect();

    _securityWorker = ever<String?>(_mwCollector.securityData, (value) {
      if (!mounted) return;
      if (value == null || value.isEmpty) return;

      _securityQueue.add(value);

      // 다음 프레임에 실행(빌드 중 호출 방지)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _drainSecurityDialogs();
      });
    });
  }

  void _startConnect() {
    if (Get.isRegistered<MwCollector>()) {
      _mwCollector = Get.find<MwCollector>();
    } else {
      _mwCollector = Get.put(
        MwCollector(
          topicFactory: (ros, name, type) =>
              Topic(ros: ros, name: name, type: type),
        ),
      );
    }
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  @override
  void dispose() {
    _securityWorker?.dispose();
    _securityWorker = null;
    super.dispose();
  }

  Future<void> _drainSecurityDialogs() async {
    if (_showingSecurityDialog) return;
    _showingSecurityDialog = true;

    try {
      while (mounted && _securityQueue.isNotEmpty) {
        final text = _securityQueue.removeAt(0);
        await _showSecurityAlert(text);
      }
    } finally {
      _showingSecurityDialog = false;
    }
  }

  Future<void> _showSecurityAlert(String text) async {
    final palette = AdswPaletteScope.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Security Alert'),
          content: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(color: palette.text, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = AdswPaletteScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Obx(() {
                  final logs = _mwCollector.notificationLogs.toList();

                  String label(DiagNotificationItem it) => it.label;

                  String value(DiagNotificationItem it) {
                    final lines = <String>[];

                    // status (숫자 + 텍스트)
                    if (it.status != null) {
                      final stText =
                          (it.statusText != null && it.statusText!.isNotEmpty)
                          ? it.statusText
                          : '${it.status}';
                      lines.add('status: $stText (${it.status})');
                    }

                    // message
                    if (it.message.trim().isNotEmpty) {
                      lines.add('message: ${it.message}');
                    }

                    // source message name
                    if (it.sourceMessageName.trim().isNotEmpty) {
                      lines.add('source: ${it.sourceMessageName}');
                    }

                    // raw_data (원문 그대로)
                    if (it.rawData.trim().isNotEmpty) {
                      lines.add('raw_data: ${it.rawData}');
                    }

                    // received_at
                    lines.add(
                      'received_at: ${it.receivedAt.toIso8601String()}',
                    );

                    return lines.isEmpty ? '-' : lines.join('\n');
                  }

                  // 상태 색상 매핑
                  StatusType statusOf(DiagNotificationItem it) {
                    // DiagnosticStatusType 매핑:
                    // 1 PASS, 2 FATAL, 3 WARNING 같은 식이면
                    switch (it.status) {
                      case 1:
                        return StatusType.good;
                      case 3:
                        return StatusType.warning;
                      case 2:
                        return StatusType.error;
                      default:
                        return StatusType.good;
                    }
                  }

                  final Widget content = logs.isEmpty
                      ? const KeyValueItem(
                          label: 'Waiting for notifications...',
                          value: '-',
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: logs.length,
                          itemBuilder: (_, i) {
                            final it = logs[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: KeyValueItem(
                                label: label(it),
                                value: value(it),
                                status: statusOf(it),
                              ),
                            );
                          },
                        );

                  return DataViewWidget(
                    title: 'Diagnostic Notifications',
                    icon: Icons.notifications_active,
                    iconColor: palette.primary,
                    status: StatusType.warning,
                    isExpanded: _expandedSections['notification'] ?? false,
                    onTap: () => _toggleSection('notification'),
                    children: [content],
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Obx(() {
            final list = _mwCollector.diagnostics;

            StatusType statusOf(int? s) {
              switch (s) {
                case 1:
                  return StatusType.good;
                case 3:
                  return StatusType.warning;
                case 2:
                  return StatusType.error;
                default:
                  return StatusType.good;
              }
            }

            String subtitle(Map<String, dynamic> raw) {
              final code = raw['code'];
              final retT = raw['ret_text'];
              final msg = raw['message'];
              final source = raw['source_message_name'];
              final rawData = raw['raw_data'];

              final lines = <String>[];
              lines.add('code: ${code ?? '-'} ret: ${retT ?? '-'}');
              if (msg != null && ('$msg').isNotEmpty) {
                lines.add('msg: $msg');
              }
              if (source != null && ('$source').isNotEmpty) {
                lines.add('source: $source');
              }
              if (rawData != null && ('$rawData').isNotEmpty) {
                lines.add('raw: $rawData');
              }
              return lines.join('\n');
            }

            final children = list.isEmpty
                ? const [
                    KeyValueItem(
                      label: 'Press refresh to load diagnostics',
                      value: '-',
                    ),
                  ]
                : [
                    // overflow 방지: 높이 제한 + 스크롤
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final raw = list[i];
                          final int? statusNum = (raw['status'] is num)
                              ? (raw['status'] as num).toInt()
                              : null;

                          final value = raw['status_text']?.toString() ?? '-';
                          final label = raw['name']?.toString() ?? 'unknown';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: KeyValueItem(
                              label: label,
                              value: value,
                              subtitle: subtitle(raw),
                              status: statusOf(statusNum),
                            ),
                          );
                        },
                      ),
                    ),
                  ];

            final bool busy = _mwCollector.isRefreshing.value;

            final Widget refreshButton = IconButton(
              tooltip: busy ? 'Refreshing...' : 'Refresh',
              color: palette.primary,
              onPressed: busy
                  ? null
                  : () async {
                      await _mwCollector.refreshOnce();
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            );

            return DataViewWidget(
              title: 'Diagnostic Info Get',
              icon: Icons.settings,
              iconColor: palette.primary,
              status: StatusType.error,
              isExpanded: _expandedSections['diagnostic'] ?? false,
              onTap: () => _toggleSection('diagnostic'),
              button: refreshButton,
              children: children,
            );
          }),
        ],
      ),
    );
  }
}
