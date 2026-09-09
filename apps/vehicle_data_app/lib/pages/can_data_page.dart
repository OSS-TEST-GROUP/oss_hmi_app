import 'package:flutter/material.dart';
import 'package:vehicle_data_app/widgets/data_card.dart';
import 'package:vehicle_data_app/services/data_cache.dart';

class CanDataPage extends StatefulWidget {
  const CanDataPage({super.key});

  @override
  State<CanDataPage> createState() => _CanDataPageState();
}

class _CanDataPageState extends State<CanDataPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _flDoor = false;
  bool _frDoor = false;
  bool _rlDoor = false;
  bool _rrDoor = false;

  static const _labelMap = {
    'Vehicle.Powertrain.CombustionEngine.Speed': 'Engine Speed',
    'Vehicle.Speed': 'Speed',
    'Vehicle.Chassis.Accelerator.PedalPosition': 'Accel Pedal',
    'Vehicle.Acceleration.Longitudinal': 'Longitudinal',
    'Vehicle.Acceleration.Lateral': 'Lateral',
    'Vehicle.Acceleration.Vertical': 'Vertical',
    'Vehicle.Chassis.SteeringWheel.Angle': 'SteeringWheel Angle',
    'Vehicle.Chassis.Brake.PedalPosition': 'Brake Pedal',
    'Vehicle.Attitude.Yaw': 'Yaw',
    'Vehicle.Attitude.Roll': 'Roll',
    'Vehicle.Attitude.Pitch': 'Pitch',
    'Vehicle.CurrentLocation.Latitude': 'Latitude',
    'Vehicle.CurrentLocation.Longitude': 'Longitude',
    'Vehicle.CurrentLocation.Altitude': 'Altitude',
    'Vehicle.CurrentLocation.Heading': 'Heading',
    'Vehicle.Body.Lights.DirectionIndicator.Left.IsSignaling': 'Left Indicator',
    'Vehicle.Body.Lights.DirectionIndicator.Right.IsSignaling': 'Right Indicator',
    'Vehicle.Body.Lights.Backup.IsOn': 'Backup Lights',
    'Vehicle.Body.Windshield.Front.Wiping.System.IsWiping': 'Wiper',
    'Vehicle.Powertrain.Transmission.TravelledDistance': 'Travelled Distance',
    'Vehicle.StartTime': 'Start Time',
    'Vehicle.Powertrain.FuelSystem.RelativeLevel': 'Fuel Level',
    'Vehicle.Exterior.AirTemperature': 'Air Temperature',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: DataCache.instance.listenable,
      builder: (context, data, _) {
        final hasData = data.isNotEmpty;

        if (!hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: Colors.grey),
                Text(
                  '여기에 전송한 데이터가 표시됩니다.\nCSV를 불러와 전송을 시작하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        String valueOf(String key) => _formatValue(data[key]);
        String labelOf(String key) => _labelMap[key] ?? key.split('.').last;

        String vehicleId = valueOf('VehicleModelID');
        String userId = valueOf('UserID');
        String time = valueOf('Timestamp');

        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('VEHICLE ID: $vehicleId / USER ID: $userId / TIMESTAMP: $time'),
              const SizedBox(height: 10,),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫번째 컬럼
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // InfoCard(
                        //   title: 'VEHICLE INFO', 
                        //   leadingIcon: Icons.speed,
                        //   items: [
                        //     {'label':'USER ID','value':valueOf('UserID')},
                        //     {'label':'VEHICLE ID','value':valueOf('VehicleModelID')},
                        //     {'label':'TIMESTAMP','value':valueOf('Timestamp')},
                        //   ],
                        // ),
                        // InfoCard(
                        //   title: 'CONTROL', 
                        //   leadingIcon: Icons.control_point,
                        //   items: [
                        //     {'label':labelOf('Vehicle.Speed'),'value':valueOf('Vehicle.Speed')},
                        //     {'label':labelOf('Vehicle.Powertrain.CombustionEngine.Speed'),'value':valueOf('Vehicle.Powertrain.CombustionEngine.Speed')},
                        //     {'label':labelOf('Vehicle.Chassis.Accelerator.PedalPosition'),'value':valueOf('Vehicle.Chassis.Accelerator.PedalPosition')},
                        //     {'label':labelOf('Vehicle.Chassis.Brake.PedalPosition'),'value':valueOf('Vehicle.Chassis.Brake.PedalPosition')},
                        //     {'label':labelOf('Vehicle.Chassis.SteeringWheel.Angle'),'value':valueOf('Vehicle.Chassis.SteeringWheel.Angle')},
                        //   ],
                        // ),
                        _vehicle1(valueOf, labelOf),
                        _vehicle6(valueOf, labelOf),
                      ],
                    ),
                  ),
                  // 두번째 컬럼
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _vehicle2(valueOf, labelOf),
                        _vehicle5(valueOf, labelOf),
                      ],
                    ),
                  ),
                  // 세번째 컬럼
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _vehicle3(valueOf, labelOf),
                        _vehicle4(valueOf, labelOf),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 75,),
            ],
          ),
        );
      },
    );
  }

  // ====== 공통 포맷터 ======
  String _formatValue(dynamic v) {
    if (v == null) return '-';
    if (v is num) {
      return (v % 1 == 0) ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
    // 문자열도 오는 경우가 있어서 다 string 처리
  }

  // ====== 섹션 위젯들 ======

  Widget _vehicle1(String Function(String) valueOf, String Function(String) labelOf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('동력 및 제어',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          Row(
            children: [
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Powertrain.CombustionEngine.Speed'),
                  value: valueOf('Vehicle.Powertrain.CombustionEngine.Speed'),
                ),
              ),
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Speed'),
                  value: valueOf('Vehicle.Speed'),
                ),
              ),
            ],
          ),
          DataCard(
            label: labelOf('Vehicle.Chassis.Accelerator.PedalPosition'),
            value: valueOf('Vehicle.Chassis.Accelerator.PedalPosition'),
          ),
          DataCard(
            label: labelOf('Vehicle.Chassis.Brake.PedalPosition'), 
            value: valueOf('Vehicle.Chassis.Brake.PedalPosition'),
          ),
          DataCard(
            label: labelOf('Vehicle.Chassis.SteeringWheel.Angle'), 
            value: valueOf('Vehicle.Chassis.SteeringWheel.Angle'),
          ),
        ],
      ),
    );
  }

  Widget _vehicle2(String Function(String) valueOf, String Function(String) labelOf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('위치 및 자세',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(
            label: labelOf('Vehicle.CurrentLocation.Latitude'), 
            value: valueOf('Vehicle.CurrentLocation.Latitude'),
          ),
          DataCard(
            label: labelOf('Vehicle.CurrentLocation.Longitude'), 
            value: valueOf('Vehicle.CurrentLocation.Longitude'),
          ),
          DataCard(
            label: labelOf('Vehicle.CurrentLocation.Altitude'), 
            value: valueOf('Vehicle.CurrentLocation.Altitude'),
          ),
          Row(
            children: [
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Attitude.Yaw'), 
                  value: valueOf('Vehicle.Attitude.Yaw'),
                ),
              ),
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Attitude.Roll'), 
                  value: valueOf('Vehicle.Attitude.Roll')
                ),
              ),
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Attitude.Pitch'), 
                  value: valueOf('Vehicle.Attitude.Pitch'),
                ),
              ),
            ],
          ),
          DataCard(
            label: labelOf('Vehicle.CurrentLocation.Heading'), 
            value: valueOf('Vehicle.CurrentLocation.Heading'),
          ),
        ],
      ),
    );
  }

  Widget _vehicle3(String Function(String) valueOf, String Function(String) labelOf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('동적 거동',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(
            label: labelOf('Vehicle.Acceleration.Longitudinal'),
            value: valueOf('Vehicle.Acceleration.Longitudinal'),
          ),
          DataCard(
            label: labelOf('Vehicle.Acceleration.Lateral'),
            value: valueOf('Vehicle.Acceleration.Lateral'),
          ),
          DataCard(
            label: labelOf('Vehicle.Acceleration.Vertical'),
            value: valueOf('Vehicle.Acceleration.Vertical'),
          ),
        ],
      ),
    );
  }

  Widget _vehicle4(String Function(String) valueOf, String Function(String) labelOf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('조명 및 신호',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          _signalRow('LeftIsSignaling', _flDoor, (v) {
            setState(() => _flDoor = v);
          }),
          _signalRow('RightIsSignaling', _frDoor, (v) {
            setState(() => _frDoor = v);
          }),
          _signalRow('BackupIsOn', _rlDoor, (v) {
            setState(() => _rlDoor = v);
          }),
          _signalRow('IsWiping', _rrDoor, (v) {
            setState(() => _rrDoor = v);
          }),
        ],
      ),
    );
  }

  Widget _vehicle5(String Function(String) valueOf, String Function(String) labelOf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('환경 및 연료',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          Row(
            children: [
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Exterior.AirTemperature'), 
                  value: valueOf('Vehicle.Exterior.AirTemperature'),
                ),
              ),
              Expanded(
                child: DataCard(
                  label: labelOf('Vehicle.Powertrain.FuelSystem.RelativeLevel'), 
                  value: valueOf('Vehicle.Powertrain.FuelSystem.RelativeLevel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicle6(String Function(String) valueOf, String Function(String) labelOf) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('주행 이력',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(
            label: labelOf('Vehicle.StartTime'), 
            value: valueOf('Vehicle.StartTime'),
          ),
          DataCard(
            label: labelOf('Vehicle.Powertrain.Transmission.TravelledDistance'), 
            value: valueOf('Vehicle.Powertrain.Transmission.TravelledDistance'),
          ),
        ],
      ),
    );
  }

  // ====== 공용 위젯 ======

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      border:
          Border.all(color: const Color.fromARGB(255, 228, 228, 228), width: 1),
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _signalRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Card.outlined(
      color: const Color.fromARGB(255, 247, 247, 247),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              activeColor: Colors.blue,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
