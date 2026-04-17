import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_monitor/logging/rolling_file_logger.dart';

/// F009: RollingFileLogger boundary behavior.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rfl_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  RollingFileLogger makeLogger({
    int maxBytes = 10 * 1024 * 1024,
    int maxFiles = 5,
    int flushLines = 1,
  }) =>
      RollingFileLogger(
        dirPath: tempDir.path,
        fileName: 'test.log',
        maxBytes: maxBytes,
        maxFiles: maxFiles,
        // Make tests deterministic: flush after every add and
        // effectively disable the background timer.
        flushEvery: const Duration(hours: 1),
        flushLines: flushLines,
      );

  Future<List<String>> listLogFiles() async {
    final list = await tempDir
        .list()
        .where((e) => e is File && e.path.contains('test.log'))
        .map((e) => e.path.split('/').last)
        .toList();
    list.sort();
    return list;
  }

  group('RollingFileLogger', () {
    test('writes lines to the main log file', () async {
      final logger = makeLogger();
      await logger.start();
      logger.addLine('hello');
      logger.addLine('world');
      await logger.flush();
      await logger.stop();

      final content = await File('${tempDir.path}/test.log').readAsString();
      expect(content, contains('hello'));
      expect(content, contains('world'));
    });

    test('rotates when writing a line would exceed maxBytes', () async {
      final logger = makeLogger(maxBytes: 60); // tiny limit
      await logger.start();

      // Four lines of ~25 bytes each → forces rotation after the second.
      for (var i = 0; i < 4; i++) {
        logger.addLine('line-number-$i-payload');
        await logger.flush();
      }
      await logger.stop();

      final files = await listLogFiles();
      expect(files, contains('test.log'));
      expect(files.any((f) => f.startsWith('test.log.')), isTrue,
          reason: 'At least one rotated file should exist');
    });

    test('keeps at most maxFiles rotated generations', () async {
      final logger = makeLogger(maxBytes: 40, maxFiles: 3);
      await logger.start();

      // Write enough lines to trigger multiple rotations.
      for (var i = 0; i < 20; i++) {
        logger.addLine('payload-$i-some-extra-filler');
        await logger.flush();
      }
      await logger.stop();

      final files = await listLogFiles();
      // Expect only: test.log, test.log.1, test.log.2  (maxFiles=3)
      // test.log.3 and higher should be pruned by the rename chain.
      final rotated = files.where((f) => f.startsWith('test.log.')).toList();
      expect(rotated.length, lessThanOrEqualTo(2),
          reason: 'rotated files capped at maxFiles-1=2, got $rotated');
    });

    test('start() immediately rotates an existing oversized file', () async {
      // Pre-seed a large log file (> maxBytes).
      final pre = File('${tempDir.path}/test.log');
      await pre.writeAsString('X' * 200);

      final logger = makeLogger(maxBytes: 100);
      await logger.start();
      await logger.stop();

      final files = await listLogFiles();
      expect(files, contains('test.log.1'),
          reason: 'start() must rotate the pre-existing large file');
      // The pre-existing content moved to .1 and is preserved.
      final rotated = await File('${tempDir.path}/test.log.1').readAsString();
      expect(rotated, 'X' * 200);
    });

    test('multiple concurrent addLine calls do not corrupt the buffer',
        () async {
      final logger = makeLogger(flushLines: 1000);
      await logger.start();

      // Fire a batch of concurrent addLine calls.
      await Future.wait(List.generate(50, (i) async {
        logger.addLine('concurrent-$i');
      }));
      await logger.flush();
      await logger.stop();

      final content = await File('${tempDir.path}/test.log').readAsString();
      final lineCount = '\n'.allMatches(content).length;
      // We don't promise ordering but every line should be present exactly
      // once — 50 lines in total.
      expect(lineCount, 50);
      for (var i = 0; i < 50; i++) {
        expect(content, contains('concurrent-$i'));
      }
    });
  });
}
