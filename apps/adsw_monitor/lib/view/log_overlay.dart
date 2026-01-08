import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class LogController extends GetxController {
  final RxList<String> lines = <String>[].obs;
  final int maxLines;
  LogController({this.maxLines = 800});

  void add(String s) {
    lines.add(s);
    if (lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
  }

  void clear() => lines.clear();
}

void runWithLogCapture(
  FutureOr<void> Function() body, {
  void Function(Object error, StackTrace st)? onError,
}) {
  if (!Get.isRegistered<LogController>()) {
    Get.put(LogController(), permanent: true);
  }

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (!Get.isRegistered<LogController>()) {
        Get.put(LogController(), permanent: true);
      }
      await body();
    },
    (e, st) {
      if (Get.isRegistered<LogController>()) {
        final log = Get.find<LogController>();
        log.add('[ZONE ERROR] $e');
        log.add(st.toString());
      }
      onError?.call(e, st);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        parent.print(zone, line);
        if (Get.isRegistered<LogController>()) {
          Get.find<LogController>().add(line);
        }
      },
    ),
  );
}

class LogBottomSheet extends StatefulWidget {
  const LogBottomSheet({super.key});

  @override
  State<LogBottomSheet> createState() => _LogBottomSheetState();
}

class _LogBottomSheetState extends State<LogBottomSheet> {
  final ScrollController _listCtrl = ScrollController();
  bool _autoFollow = true;

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_listCtrl.hasClients) return;
    _listCtrl.jumpTo(_listCtrl.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final log = Get.find<LogController>();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (context, sheetScrollController) {
        // sheetScrollController - 시트 높이 드래그
        // 실제 리스트 스크롤 - _listCtrl
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B1220),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const Expanded(
                      child: Text('Debug Log',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      tooltip: _autoFollow ? 'Auto-follow: ON' : 'Auto-follow: OFF',
                      onPressed: () => setState(() => _autoFollow = !_autoFollow),
                      icon: Icon(_autoFollow ? Icons.south : Icons.south_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Jump bottom',
                      onPressed: _scrollToBottom,
                      icon: const Icon(Icons.arrow_downward, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () => log.clear(),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(() {
                  final items = log.lines;

                  if (_autoFollow) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }

                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No logs yet...', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    controller: _listCtrl,
                    itemCount: items.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        items[i],
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
