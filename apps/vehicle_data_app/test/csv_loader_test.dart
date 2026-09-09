import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/services/csv_loader.dart';

void main() {
  group('CsvLoader Tests', () {
    test('parseString parses standard CSV with headers and data', () {
      const csv = 'Time, Vehicle Speed , Engine RPM\n'
          '0.1, 60, 2500\n'
          '0.2, 62, 2550\n';

      final table = CsvLoader.parseString(csv, fileName: 'sample.csv');
      expect(table.fileName, 'sample.csv');
      expect(table.headers, ['Time', 'Vehicle Speed', 'Engine RPM']);
      expect(table.rows.length, 2);
      expect(table.rows[0], [0.1, 60, 2500]);
    });

    test('parseString handles BOM and CRLF line endings and comment line', () {
      const csv = '\uFEFF# StartTime = 2026-08-25 12:00:00\r\n'
          '# Second comment to ignore\r\n'
          'Time,Speed\r\n'
          '1.0,80\r\n';

      final table = CsvLoader.parseString(csv);
      expect(table.rawFirstLine, '# StartTime = 2026-08-25 12:00:00');
      expect(table.headers, ['Time', 'Speed']);
      expect(table.rows.length, 1);
    });

    test('parseString handles empty and whitespace-only text', () {
      final table1 = CsvLoader.parseString('');
      expect(table1.headers, isEmpty);
      expect(table1.rows, isEmpty);

      final table2 = CsvLoader.parseString('   \n\n\n');
      expect(table2.headers, isEmpty);
      expect(table2.rows, isEmpty);
    });

    test('parseBytes decodes bytes correctly', () {
      final bytes = [84, 105, 109, 101, 44, 83, 112, 101, 101, 100, 10, 49, 44, 50]; // Time,Speed\n1,2
      final table = CsvLoader.parseBytes(bytes, fileName: 'bytes.csv');
      expect(table.headers, ['Time', 'Speed']);
      expect(table.rows.length, 1);
    });
  });
}
