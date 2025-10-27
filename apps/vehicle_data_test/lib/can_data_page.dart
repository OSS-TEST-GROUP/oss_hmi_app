//import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vehicle_data_test/widgets/data_card.dart';
import 'package:vehicle_data_test/services/sim_bus.dart';
import 'package:vehicle_data_test/services/data_cache.dart';

class CanDataPage extends StatefulWidget {
  const CanDataPage({
    super.key,
  });

  @override
  State<CanDataPage> createState() => _CanDataPageState();
}

class _CanDataPageState extends State<CanDataPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  //List<List<String>> _canData = [];
  Map<String, dynamic>? _data = {};

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
    'Vehicle.Acceleration.Vertical': 'Vertical'
  };

  @override
  void initState() {
    super.initState();
    _loadCsvFile();
  }

  Future<void> _loadCsvFile() async {
  final csvData = await rootBundle.loadString('assets/csv/can_test.csv');

  final normalized = csvData.replaceAll(RegExp(r'\r\n?'), '\n'); // \r\n, \r 모두 \n으로
  final rows = const CsvToListConverter(eol: '\n').convert(normalized); // 파서에 eol 지정

  final mapped = _rowsToMap(rows);
  _onCsvRowParsed(mapped);

}

  Map<String, dynamic> _rowsToMap(List<List<dynamic>> rows) {
    final map = <String, dynamic>{};
    for (final r in rows.skip(1)) {
      if (r.length < 3) continue;
      map[r[0].toString()] = r[2];
    }

    return map;
  }

  String _formatValue(dynamic v) {
    if (v == null) return '-';
    if (v is num) {
      return (v % 1 == 0) ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  String labelOf(String key) => _labelMap[key] ?? key.split('.').last;
  String valueOf(String key) => _formatValue(_data?[key]);

  void _onCsvRowParsed(Map<String, dynamic> m) {

    setState(() => _data = m);
    DataCache.instance.update(m);
    //SimulatorBus.instance.pushData(m);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _vehicle1(),
                _vehicle6(),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _vehicle2(),
                _vehicle5(),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _vehicle3(),
                _vehicle4(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _files() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('데이터 파일',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('data.csv', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _vehicle1() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('동력 및 제어',
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
                  label: _labelMap['Vehicle.Speed']!,
                  value: valueOf('Vehicle.Speed'),
                ),
              ),
            ],
          ),
          DataCard(
            label: _labelMap['Vehicle.Chassis.Accelerator.PedalPosition']!,
            value: valueOf('Vehicle.Chassis.Accelerator.PedalPosition'),
          ),
          DataCard(label: 'BrakePedalPosition', value: 'value'),
          DataCard(label: 'SteeringAngle', value: 'value'),
        ],
      ),
    );
  }

  Widget _vehicle2() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('위치 및 자세',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          Text('Latitude'),
          Card.outlined(
            color: const Color.fromARGB(255, 235, 235, 235),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('0%'),
            ),
          ),
          DataCard(label: 'Longitude', value: 'value'),
          DataCard(label: 'Altitude', value: 'value'),
          Row(
            children: [
              Expanded(
                child: DataCard(label: 'Yaw', value: 'value'),
              ),
              Expanded(
                child: DataCard(label: 'Roll', value: 'value'),
              ),
              Expanded(
                child: DataCard(label: 'Pitch', value: 'value'),
              ),
            ],
          ),
          DataCard(label: 'Heading', value: 'value'),
        ],
      ),
    );
  }

  Widget _vehicle3() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('동적 거동',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(
            label: labelOf('Vehicle.Acceleration.Longitudinal'), 
            value: valueOf('Vehicle.Acceleration.Longitudinal')),
          DataCard(
            label:labelOf('Vehicle.Acceleration.Lateral'), 
            value: valueOf('Vehicle.Acceleration.Lateral')),
          DataCard(
            label: labelOf('Vehicle.Acceleration.Vertical'), 
            value: valueOf('Vehicle.Acceleration.Vertical')),
        ],
      ),
    );
  }

  Widget _vehicle4() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('조명 및 신호',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          Card.outlined(
            color: const Color.fromARGB(255, 247, 247, 247),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Checkbox(
                    value: _flDoor,
                    onChanged: (bool? value) {
                      setState(() {
                        _flDoor = value!;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  Text('LeftIsSignalling'),
                ],
              ),
            ),
          ),
          Card.outlined(
            color: const Color.fromARGB(255, 247, 247, 247),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Checkbox(
                    value: _flDoor,
                    onChanged: (bool? value) {
                      setState(() {
                        _flDoor = value!;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  Text('RightIsSignalling'),
                ],
              ),
            ),
          ),
          Card.outlined(
            color: const Color.fromARGB(255, 247, 247, 247),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Checkbox(
                    value: _flDoor,
                    onChanged: (bool? value) {
                      setState(() {
                        _flDoor = value!;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  Text('BackupIsOn'),
                ],
              ),
            ),
          ),
          Card.outlined(
            color: const Color.fromARGB(255, 247, 247, 247),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Checkbox(
                    value: _flDoor,
                    onChanged: (bool? value) {
                      setState(() {
                        _flDoor = value!;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  Text('IsWiping'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicle5() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('환경 및 연료',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          Row(
            children: [
              Expanded(
                child: DataCard(label: 'AirTemperature', value: 'value'),
              ),
              Expanded(
                child: DataCard(label: 'RelativeLevel', value: 'value'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicle6() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('주행 이력',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          DataCard(label: 'StartTime', value: 'value'),
          DataCard(label: 'TravelledDistance', value: 'value'),
        ],
      ),
    );
  }

  Widget _door() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: const Color.fromARGB(255, 212, 212, 212), width: 1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('도어 상태',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(thickness: 0.5, color: Colors.grey),
          Column(
            children: [
              Card.outlined(
                color: const Color.fromARGB(255, 247, 247, 247),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _flDoor,
                        onChanged: (bool? value) {
                          setState(() {
                            _flDoor = value!;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      Text('Front Left Door'),
                    ],
                  ),
                ),
              ),
              Card.outlined(
                color: const Color.fromARGB(255, 247, 247, 247),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _frDoor,
                        onChanged: (bool? value) {
                          setState(() {
                            _frDoor = value!;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      Text('Front Right Door'),
                    ],
                  ),
                ),
              ),
              Card.outlined(
                color: const Color.fromARGB(255, 247, 247, 247),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rlDoor,
                        onChanged: (bool? value) {
                          setState(() {
                            _rlDoor = value!;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      Text('Rear Left Door'),
                    ],
                  ),
                ),
              ),
              Card.outlined(
                color: const Color.fromARGB(255, 247, 247, 247),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rrDoor,
                        onChanged: (bool? value) {
                          setState(() {
                            _rrDoor = value!;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      Text('Rear Right Door'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
