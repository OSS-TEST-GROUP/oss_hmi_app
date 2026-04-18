import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:ota_monitor/view/log_overlay.dart';

/// F006: single logging entry point for non-UI code. Routes messages to
/// [LogController] when it is registered (production path, also backs
/// rolling_file_logger) and falls back to [debugPrint] otherwise (test
/// harness, early startup).
void appLog(String message, {String level = 'info'}) {
  if (Get.isRegistered<LogController>()) {
    Get.find<LogController>().log(message, level: level);
    return;
  }
  final tag = level == 'info' ? '' : '[$level] ';
  debugPrint('$tag$message');
}
