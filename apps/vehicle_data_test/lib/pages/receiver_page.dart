import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vehicle_data_test/grpc/grpc_client.dart';
import 'package:vehicle_data_test/src/generated/VISSv3.0.pb.dart';

class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key, required this.cloud});
  final GrpcClient cloud;

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // UI 상태
  final TextEditingController _ipController =
      TextEditingController(text: '127.0.0.1'); // 기본값은 필요에 따라 변경
  final TextEditingController _portController =
      TextEditingController(text: '50052'); // 기본 포트값

  final List<String> _paths = const [
    'Vehicle.Speed',
    'Vehicle.Powertrain.CombustionEngine.Speed',
    //'Vehicle.Chassis.SteeringWheel.Angle',
    // 'Vehicle.Chassis.Brake.PedalPosition',
    'Vehicle.Acceleration.Longitudinal',
    'Vehicle.Acceleration.Lateral',
    'Vehicle.Acceleration.Vertical',
    'Vehicle.Attitude.Yaw',
    'Vehicle.Attitude.Roll',
    'Vehicle.Attitude.Pitch',
    'Vehicle.CurrentLocation.Latitude',
    'Vehicle.CurrentLocation.Longitude',
    'Vehicle.CurrentLocation.Altitude',
    // 'Vehicle.CurrentLocation.Heading',
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

  String? _selectedPath;
  bool _isConnecting = false;
  bool _isConnected = false;

  StreamSubscription? _eventSub; // 필요시 직접 listen할 때 쓰려고 남겨둔 것

  @override
  void initState() {
    super.initState();
    _selectedPath = _paths.first;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _onConnectPressed() async {
    final host = _ipController.text.trim();
    final portText = _portController.text.trim();
    final path = _selectedPath ?? 'Vehicle.*';

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 IP를 입력해 주세요.')),
      );
      return;
    }

    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 포트 번호를 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      await widget.cloud.connectTo(
        host: host,
        port: port,
        path: path,
      );
      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      debugPrint('[ReceiverPage] connect error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('연결 실패: $e')),
      );
      setState(() {
        _isConnected = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _onPathChanged(String? newPath) async {
    if (newPath == null) return;
    setState(() {
      _selectedPath = newPath;
    });

    // 이미 서버에 연결되어 있으면 path만 바꿔서 다시 subscribe
    if (widget.cloud.isConnected) {
      try {
        await widget.cloud.changePath(newPath);
      } catch (e) {
        debugPrint('[ReceiverPage] changePath error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('경로 변경 실패: $e')),
        );
      }
    }
  }

  Widget _buildControlPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromARGB(255, 228, 228, 228),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 첫 줄: IP 입력 + 포트 입력 + 연결 버튼
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                // IP 입력
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: '서버 IP 주소',
                      hintText: '예: 192.168.0.10',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 포트 입력
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '포트',
                      hintText: '50052',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // 연결 버튼
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _onConnectPressed,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link, color: Colors.white),
                    label: Text(
                      _isConnected ? 'GET AGAIN' : 'GET',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isConnected ? Colors.orange : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 두 번째 줄: path 선택 드롭다운 + 상태 표시
          Padding(
            padding: const EdgeInsets.only(left:15, right:15),
            child: Row(
              children: [
                const Text(
                  '받을 데이터 경로',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedPath,
                  items: _paths
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p),
                        ),
                      )
                      .toList(),
                  onChanged: _onPathChanged,
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? '연결됨' : '연결 안 됨',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataList() {
    return StreamBuilder<DataPackages>(
      stream: widget.cloud.events,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Text(
              '수신 대기 중...',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        final dp = snapshot.data!;
        final rows = <Widget>[];
        for (final pkg in dp.data) {
          for (final p in pkg.dp) {
            rows.add(
              ListTile(
                title: Text(pkg.path),
                subtitle: Text(p.ts),
                trailing: Text(p.value),
              ),
            );
          }
        }
        if (rows.isEmpty) {
          return const Center(child: Text('데이터 없음'));
        }
        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
          child: ListView.separated(
            itemBuilder: (_, i) {
              if (i < rows.length) {
                return rows[i];
              }
              return const SizedBox(height: 75);
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: rows.length + 1,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildControlPanel(),
        Expanded(child: _buildDataList()),
      ],
    );
  }
}
