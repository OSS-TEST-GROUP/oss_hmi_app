import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/services/csv_loader.dart';
import 'package:vehicle_data_app/services/csv_playback.dart';
import 'package:vehicle_data_app/services/data_cache.dart';

void main() {
  group('CsvPlayback Tests', () {
    test('playback lifecycle start, ticks, and stop', () async {
      final headers = ['Vehicle speed (MPH)', 'Engine RPM (RPM)'];
      final rows = [
        ['30.0', '1500'],
        ['40.0', '2000'],
        ['50.0', '2500'],
      ];
      final table = CsvTable(headers, rows, fileName: 'test.csv');

      final playback = CsvPlayback(table);
      expect(playback.totalRows, 3);
      expect(playback.currentIndex, 0);
      expect(playback.isRunning, isFalse);

      playback.start(interval: const Duration(milliseconds: 50));
      expect(playback.isRunning, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(playback.currentIndex, greaterThanOrEqualTo(2));
      expect(DataCache.instance.last.isNotEmpty, isTrue);

      playback.stop();
      expect(playback.isRunning, isFalse);

      playback.reset();
      expect(playback.currentIndex, 0);
    });

    test('start on empty table does not run', () {
      final emptyTable = CsvTable([], []);
      final playback = CsvPlayback(emptyTable);
      playback.start();
      expect(playback.isRunning, isFalse);
    });
  });
}
