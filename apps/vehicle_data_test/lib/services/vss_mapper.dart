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
    'Vehicle.Body.Lights.DirectionIndicator.Left.IsSignalling',
    'Vehicle.Body.Lights.DirectionIndicator.Right.IsSignalling',
    'Vehicle.Body.Lights.Backup.IsOn',
    'Vehicle.Body.Windshield.Front.Wiping.System.IsWiping',
    'Vehicle.Powertrain.Transmission.TravelledDistance',
    'Vehicle.StartTime',
    'Vehicle.Chassis.Accelerator.PedalPosition',
    'Vehicle.Powertrain.FuelSystem.RelativeLevel',
    'Vehicle.Exterior.AirTemperature',
  ];

  static String _canon(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ');

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

  // 헤더 → (vss path, 변환기)
  late final Map<String, (String path, Transform? tx)> _map = {
    _canon('Vehicle speed (MPH)'):
        ('Vehicle.Speed', useSiUnits ? _milesToKm : null),
    _canon('Engine RPM (RPM)'):
        ('Vehicle.Powertrain.CombustionEngine.Speed', null),
    _canon('Accelerator pedal position D (%)'):
        ('Vehicle.Chassis.Accelerator.PedalPosition', null),
    _canon('Fuel level input (%)'):
        ('Vehicle.Powertrain.FuelSystem.RelativeLevel', null),
    _canon('Trip Distance (miles)'):
        ('Vehicle.Powertrain.Transmission.TravelledDistance',
            useSiUnits ? _milesToKm : null),
    _canon('Time since engine start (sec)'):
        ('Vehicle.StartTime', null),
    _canon('Latitude (deg)'):
        ('Vehicle.CurrentLocation.Latitude', null),
    _canon('Longitude (deg)'):
        ('Vehicle.CurrentLocation.Longitude', null),
    _canon('Accel X (ft/s²)'):
        ('Vehicle.Acceleration.Longitudinal',
            useSiUnits ? _ftps2ToMs2 : null),
    _canon('Accel Y (ft/s²)'):
        ('Vehicle.Acceleration.Lateral',
            useSiUnits ? _ftps2ToMs2 : null),
    _canon('Accel Z (ft/s²)'):
        ('Vehicle.Acceleration.Vertical',
            useSiUnits ? _ftps2ToMs2 : null),
    _canon('Yaw (deg)'):
        ('Vehicle.Attitude.Yaw', null),
    _canon('Roll (deg)'):
        ('Vehicle.Attitude.Roll', null),
    _canon('Pitch (deg)'):
        ('Vehicle.Attitude.Pitch', null),
    _canon('Ambient air temperature (°F)'):
        ('Vehicle.Exterior.AirTemperature',
            useSiUnits ? _fToC : null),
  };

  /// CSV 한 줄 -> 우리가 보내는 완성 VSS 맵
  Map<String, dynamic> rowToVssFull(
    List<String> headers,
    List<dynamic> row,
  ) {
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

      final value =
          transformer == null ? raw : transformer(raw);

      // 숫자 시도
      final num? asNum =
          value is num ? value : num.tryParse(value.toString());
      out[vssPath] = asNum ?? value.toString();
    }

    // 2) 메타/고정 필드 주입
    out['Timestamp'] = DateTime.now().toUtc().toIso8601String();
    out['VehicleModelID'] = defaultVehicleModelId;
    out['UserID'] = defaultUserId;

    // 3) 없는 애들은 null / '-' 로 채우기
    for (final key in kRequiredKeys) {
      if (!out.containsKey(key)) {
        out[key] = null;
        //out[key] = '-';
      }
    }

    return out;
  }

  /// 테이블의 마지막 행을 기준으로 완성 VSS 맵 만들기
  Map<String, dynamic> lastRowToVssFull(
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      // 행이 하나도 없을 때도 완전한 형태로 반환
      final m = <String, dynamic>{
        'Timestamp': DateTime.now().toUtc().toIso8601String(),
        'VehicleModelID': defaultVehicleModelId,
        'UserID': defaultUserId,
      };
      for (final key in kRequiredKeys) {
        m.putIfAbsent(key, () => '-');
      }
      return m;
    }
    return rowToVssFull(headers, rows.last);
  }
}