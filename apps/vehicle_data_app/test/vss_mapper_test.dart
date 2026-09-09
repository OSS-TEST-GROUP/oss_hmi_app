import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/services/csv_loader.dart';
import 'package:vehicle_data_app/services/vss_mapper.dart';

void main() {
  group('VssMapper Tests', () {
    test('tryParseKoreanStartTimeToIso parses AM/PM formats correctly', () {
      final mapper = VssMapper();

      final morning = mapper.tryParseKoreanStartTimeToIso(
          '# StartTime = 05. 14. 2024 09:30:15.123 오전');
      expect(morning, isNotNull);
      expect(morning, contains('2024-05-14'));

      final afternoon = mapper.tryParseKoreanStartTimeToIso(
          '# StartTime = 11. 20. 2024 03:15:30.500 오후');
      expect(afternoon, isNotNull);
      expect(afternoon, contains('2024-11-20'));

      final invalid = mapper.tryParseKoreanStartTimeToIso('Invalid line format');
      expect(invalid, isNull);

      final invalidPrefix = mapper.tryParseKoreanStartTimeToIso('# StartTime = bad');
      expect(invalidPrefix, isNull);
    });

    test('rowToVssFull transforms raw CSV row into full VSS schema', () {
      final mapper = VssMapper(
        useSiUnits: true,
        defaultVehicleModelId: 'test-model',
        defaultUserId: 'test-user',
      );

      final headers = [
        'Vehicle speed (MPH)',
        'Engine RPM (RPM)',
        'Accelerator pedal position D (%)',
        'Fuel level input (%)',
        'Trip Distance (miles)',
        'Latitude (deg)',
        'Longitude (deg)',
        'Accel X (ft/s²)',
        'Accel Y (ft/s²)',
        'Accel Z (ft/s²)',
        'Yaw (deg)',
        'Roll (deg)',
        'Pitch (deg)',
        'Ambient air temperature (°F)',
        'Altitude (ft)',
      ];

      final row = [
        '60.0', // Speed (miles to km)
        '2500', // RPM
        '35.5', // Accel pedal
        '80',   // Fuel
        '10.0', // Trip distance (miles to km)
        '37.5665', // Lat
        '126.9780', // Long
        '3.28', // Accel X (ft/s^2 to m/s^2)
        '0.0',
        '9.8',
        '45.0', // Yaw
        '1.2',
        '-0.5',
        '68.0', // Temp (F to C)
        '150.0', // Alt
      ];

      final table = CsvTable(
        headers,
        [row],
        fileName: 'test.csv',
        rawFirstLine: '# StartTime = 05. 14. 2024 10:00:00.000 오전',
      );

      final vss = mapper.rowToVssFull(table, 0);

      expect(vss['VehicleModelID'], 'test-model');
      expect(vss['UserID'], 'test-user');
      expect(vss['Vehicle.Speed'], closeTo(96.56, 0.1)); // 60 * 1.609344
      expect(vss['Vehicle.Powertrain.CombustionEngine.Speed'], 2500);
      expect(vss['Vehicle.CurrentLocation.Latitude'], 37.5665);
      expect(vss['Vehicle.CurrentLocation.Longitude'], 126.9780);
      expect(vss['Vehicle.Exterior.AirTemperature'], closeTo(20.0, 0.1)); // (68 - 32) * 5/9
      expect(vss['Vehicle.StartTime'], isNotNull);

      // Check required dummy defaults
      expect(vss['Vehicle.Body.Lights.DirectionIndicator.Left.IsSignaling'], false);
      expect(vss['Vehicle.Body.Lights.DirectionIndicator.Right.IsSignaling'], false);
      expect(vss['Vehicle.Body.Lights.Backup.IsOn'], false);
      expect(vss['Vehicle.Body.Windshield.Front.Wiping.System.IsWiping'], false);
    });

    test('rowToVssFull handles non-SI units without conversion', () {
      final mapper = VssMapper(useSiUnits: false);
      final headers = ['Vehicle speed (MPH)'];
      final row = ['55.0'];
      final table = CsvTable(headers, [row]);

      final vss = mapper.rowToVssFull(table, 0);
      expect(vss['Vehicle.Speed'], 55.0);
    });
  });
}
