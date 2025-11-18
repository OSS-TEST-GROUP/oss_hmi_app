import 'csv_loader.dart';

typedef Transform = dynamic Function(dynamic raw);

class VssMapper {
  VssMapper({
    this.useSiUnits = false,
    this.defaultVehicleModelId = 'demo-vehicle',
    this.defaultUserId = 'demo-user',
  });

  final bool useSiUnits;
  final String defaultVehicleModelId;
  final String defaultUserId;

  static const List<String> kRequiredKeys = [
    'Timestamp',
    'VehicleModelID',
    'UserID',
    'Vehicle.Speed',
    'Vehicle.Powertrain.CombustionEngine.Speed',
    'Vehicle.Chassis.SteeringWheel.Angle',
    'Vehicle.Chassis.Brake.PedalPosition',
    'Vehicle.Acceleration.Longitudinal',
    'Vehicle.Acceleration.Lateral',
    'Vehicle.Acceleration.Vertical',
    'Vehicle.Attitude.Yaw',
    'Vehicle.Attitude.Roll',
    'Vehicle.Attitude.Pitch',
    'Vehicle.CurrentLocation.Latitude',
    'Vehicle.CurrentLocation.Longitude',
    'Vehicle.CurrentLocation.Altitude',
    'Vehicle.CurrentLocation.Heading',
    'Vehicle.Body.Lights.DirectionIndicator.Left.IsSignaling',
    'Vehicle.Body.Lights.DirectionIndicator.Right.IsSignaling',
    'Vehicle.Body.Lights.Backup.IsOn',
    'Vehicle.Body.Windshield.Front.Wiping.System.IsWiping',
    'Vehicle.Powertrain.Transmission.TravelledDistance',
    'Vehicle.StartTime',
    'Vehicle.Chassis.Accelerator.PedalPosition',
    'Vehicle.Powertrain.FuelSystem.RelativeLevel',
    'Vehicle.Exterior.AirTemperature',
  ];

  static String _canon(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  // ===== 단위 변환 =====
  num? _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v.toString().trim());
  }

  // dynamic _mphToMs(dynamic v) {
  //   final n = _toNum(v);
  //   if (n == null) return v;
  //   return n * 0.44704;
  // }

  dynamic _milesToKm(dynamic v) {
    final n = _toNum(v);
    if (n == null) return v;
    return n * 1.609344;
  }

  dynamic _ftps2ToMs2(dynamic v) {
    final n = _toNum(v);
    if (n == null) return v;
    return n * 0.3048;
  }

  dynamic _fToC(dynamic v) {
    final n = _toNum(v);
    if (n == null) return v;
    return (n - 32) * 5 / 9;
  }

  String? tryParseKoreanStartTimeToIso(String line) {
    const prefix = '# StartTime = ';
    if (!line.startsWith(prefix)) return null;
    var raw = line.substring(prefix.length).trim();

    bool isPm = false;
    if (raw.endsWith('오전')) {
      raw = raw.replaceAll(' 오전', '').trim();
    } else if (raw.endsWith('오후')) {
      raw = raw.replaceAll(' 오후', '').trim();
      isPm = true;
    }

    final parts = raw.split(' ');
    if (parts.length < 4) return null;

    final month = parts[0].replaceAll('.', '').trim();
    final day = parts[1].replaceAll('.', '').trim();
    final year = parts[2];
    final time = parts[3];

    final timeParts = time.split(':');
    if (timeParts.length < 3) return null;

    final hourStr = timeParts[0];
    final minuteStr = timeParts[1];
    final secAndMs = timeParts[2].split('.');
    final secondStr = secAndMs[0];
    final msStr = secAndMs.length > 1 ? secAndMs[1] : '0';

    int hour = int.parse(hourStr);
    final minute = int.parse(minuteStr);
    final second = int.parse(secondStr);

    final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));

    if (isPm && hour < 12) {
      hour += 12;
    }
    if (!isPm && hour == 12) {
      hour = 0;
    }

    final dtLocal = DateTime(
      int.parse(year),
      int.parse(month),
      int.parse(day),
      hour,
      minute,
      second,
      ms,
    );

    return dtLocal.toUtc().toIso8601String();
  }

  String? _parseKoreanStartTime(String? line) {
    if (line == null) return null;
    return tryParseKoreanStartTimeToIso(line);
  }

  // 헤더 → (vss path, 변환기)
  late final Map<String, (String path, Transform? tx)> _map = {
    _canon('Vehicle speed (MPH)'): (
      'Vehicle.Speed',
      useSiUnits ? _milesToKm : null
    ),
    _canon('Engine RPM (RPM)'): (
      'Vehicle.Powertrain.CombustionEngine.Speed',
      null
    ),
    _canon('Accelerator pedal position D (%)'): (
      'Vehicle.Chassis.Accelerator.PedalPosition',
      null
    ),
    _canon('Fuel level input (%)'): (
      'Vehicle.Powertrain.FuelSystem.RelativeLevel',
      null
    ),
    _canon('Trip Distance (miles)'): (
      'Vehicle.Powertrain.Transmission.TravelledDistance',
      useSiUnits ? _milesToKm : null
    ),
    // _canon('Time since engine start (sec)'):
    //     ('Vehicle.StartTime', null),
    _canon('Latitude (deg)'): ('Vehicle.CurrentLocation.Latitude', null),
    _canon('Longitude (deg)'): ('Vehicle.CurrentLocation.Longitude', null),
    _canon('Accel X (ft/s²)'): (
      'Vehicle.Acceleration.Longitudinal',
      useSiUnits ? _ftps2ToMs2 : null
    ),
    _canon('Accel Y (ft/s²)'): (
      'Vehicle.Acceleration.Lateral',
      useSiUnits ? _ftps2ToMs2 : null
    ),
    _canon('Accel Z (ft/s²)'): (
      'Vehicle.Acceleration.Vertical',
      useSiUnits ? _ftps2ToMs2 : null
    ),
    _canon('Yaw (deg)'): ('Vehicle.Attitude.Yaw', null),
    _canon('Roll (deg)'): ('Vehicle.Attitude.Roll', null),
    _canon('Pitch (deg)'): ('Vehicle.Attitude.Pitch', null),
    _canon('Ambient air temperature (°F)'): (
      'Vehicle.Exterior.AirTemperature',
      useSiUnits ? _fToC : null
    ),
    _canon('Altitude (ft)'): ('Vehicle.CurrentLocation.Altitude', null),
  };

  /// CSV 한 줄 -> 우리가 보내는 완성 VSS 맵
  Map<String, dynamic> rowToVssFull(
    CsvTable table,
    int rowIndex,
    // List<String> headers,
    // List<dynamic> row,
  ) {
    final headers = table.headers;
    final row = table.rows[rowIndex];

    // CSV에 있는 것들로 맵 구성
    final out = <String, dynamic>{};

    for (int i = 0; i < headers.length && i < row.length; i++) {
      final canon = _canon(headers[i]);
      final entry = _map[canon];
      if (entry == null) continue;

      final raw = row[i];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isEmpty) continue;

      // final (path: vssPath, tx: transformer) = entry;
      final vssPath = entry.$1;
      final transformer = entry.$2;

      final value = transformer == null ? raw : transformer(raw);

      // 숫자 시도
      final num? asNum = value is num ? value : num.tryParse(value.toString());
      out[vssPath] = asNum ?? value.toString();
    }

    String timeStamp =
        DateTime.now().toUtc().toIso8601String().replaceFirstMapped(
              RegExp(r'\.(\d+)(Z|$)'),
              (m) => '.${m[1]!.substring(0, 3)}Z',
            );

    // 2) 메타/고정 필드 주입
    out['Timestamp'] = timeStamp;
    out['VehicleModelID'] = defaultVehicleModelId;
    out['UserID'] = defaultUserId;

    // start time 맨 위 행으로 채우기
    final isoFromHeader = _parseKoreanStartTime(table.rawFirstLine);
    if (isoFromHeader != null) {
      out['Vehicle.StartTime'] = isoFromHeader;
    }

    // 3) 없는 애들은 null / '-' 로 채우기
    for (final key in kRequiredKeys) {
      if (!out.containsKey(key)) {
        out[key] = null;
        //out[key] = '-';
      }
    }

    const dummyDefaults = {
      'Vehicle.Attitude.Yaw': 0.0,
      'Vehicle.Body.Lights.DirectionIndicator.Left.IsSignaling': false,
      'Vehicle.Body.Lights.DirectionIndicator.Right.IsSignaling': false,
      'Vehicle.Body.Lights.Backup.IsOn': false,
      'Vehicle.Body.Windshield.Front.Wiping.System.IsWiping': false,
    };

// dummyDefaults에 있는 키만 덮어쓰기
    dummyDefaults.forEach((key, value) {
      if (out[key] == null) {
        out[key] = value;
      }
    });

    return out;
  }

  /// 테이블의 마지막 행을 기준으로 완성 VSS 맵 만들기
  // Map<String, dynamic> lastRowToVssFull(
  //   CsvTable table,
  //   // List<String> headers,
  //   // List<List<dynamic>> rows,
  // ) {

  //   final headers = table.headers;
  //   final rows = table.rows;

  //   if (rows.isEmpty) {
  //     // 행이 하나도 없을 때도 완전한 형태로 반환
  //     final m = <String, dynamic>{
  //       'Timestamp': DateTime.now().toUtc().toIso8601String(),
  //       'VehicleModelID': defaultVehicleModelId,
  //       'UserID': defaultUserId,
  //     };
  //     for (final key in kRequiredKeys) {
  //       m.putIfAbsent(key, () => '-');
  //     }
  //     return m;
  //   }
  //   return rowToVssFull(table, table);
  // }
}
