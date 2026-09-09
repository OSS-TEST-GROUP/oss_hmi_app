import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:diag_monitor/logging/rolling_file_logger.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rfl_diag_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  RollingFileLogger makeLogger({
    int maxBytes = 10 * 1024 * 1024,
    int maxFiles = 5,
    int flushLines = 50,
  }) =>
      RollingFileLogger(
        dirPath: tempDir.path,
        fileName: 'diag_test.log',
        maxBytes: maxBytes,
        maxFiles: maxFiles,
        flushEvery: const Duration(hours: 1),
        flushLines: flushLines,
      );

  Future<List<String>> listLogFiles() async {
    final list = await tempDir
        .list()
        .where((e) => e is File && e.path.contains('diag_test.log'))
        .map((e) => e.path.split('/').last)
        .toList();
    list.sort();
    return list;
  }

  group('RollingFileLogger (diag_monitor)', () {
    test('writes lines to the main log file', () async {
      final logger = makeLogger();
      await logger.start();
      logger.addLine('hello');
      logger.addLine('world');
      await logger.flush();
      await logger.stop();

      final content = await File('${tempDir.path}/diag_test.log').readAsString();
      expect(content, contains('hello'));
      expect(content, contains('world'));
    });

    test('rotates when writing a line would exceed maxBytes', () async {
      final logger = makeLogger(maxBytes: 60);
      await logger.start();

      for (var i = 0; i < 4; i++) {
        logger.addLine('line-number-$i-payload');
        await logger.flush();
      }
      await logger.stop();

      final files = await listLogFiles();
      expect(files, contains('diag_test.log'));
      expect(files.any((f) => f.startsWith('diag_test.log.')), isTrue);
    });

    test('start() immediately rotates an existing oversized file', () async {
      final pre = File('${tempDir.path}/diag_test.log');
      await pre.writeAsString('A' * 200);

      final logger = makeLogger(maxBytes: 100);
      await logger.start();
      await logger.stop();

      final files = await listLogFiles();
      expect(files, contains('diag_test.log.1'));
      final rotated = await File('${tempDir.path}/diag_test.log.1').readAsString();
      expect(rotated, 'A' * 200);
    });

    test('multiple concurrent addLine calls', () async {
      final logger = makeLogger(flushLines: 1000);
      await logger.start();

      await Future.wait(List.generate(30, (i) async {
        logger.addLine('concurrent-$i');
      }));
      await logger.flush();
      await logger.stop();

      final content = await File('${tempDir.path}/diag_test.log').readAsString();
      expect(content, contains('concurrent-0'));
      expect(content, contains('concurrent-29'));
    });
  });
}
