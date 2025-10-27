import 'package:flutter/material.dart';
import 'package:vehicle_data_test/can_data_page.dart';
import 'package:vehicle_data_test/obd_data_page.dart';
import 'package:vehicle_data_test/grpc/grpc_server.dart';
import 'package:vehicle_data_test/services/sim_bus.dart';
import 'package:vehicle_data_test/services/data_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[main] before start()');

  // 서버를 백그라운드로 시작 (UI 블로킹 방지)
  try {
    await GrpcServer.instance.start(port: 50052, address: '0.0.0.0');
    debugPrint('[main] start() returned');
  } catch (e) {
    // ignore: avoid_print
    print('Failed to start gRPC server: $e');
  }
  runApp(const VehicleTestApp());
}

class VehicleTestApp extends StatelessWidget {
  const VehicleTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Data Test App',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 245, 251, 253),
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        // useMaterial3: true,
      ),
      home: const VehicleHomePage(title: 'Vehicle Data Test'),
    );
  }
}

class VehicleHomePage extends StatefulWidget {
  const VehicleHomePage({super.key, required this.title});
  final String title;

  @override
  State<VehicleHomePage> createState() => _VehicleHomePageState();
}

class _VehicleHomePageState extends State<VehicleHomePage> with SingleTickerProviderStateMixin {

  bool _isSending = false;
  bool _showBottomState = false;

  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    GrpcServer.instance.stop();
    _tabController.dispose();
    super.dispose();
  }

  Widget _header() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color:const Color.fromARGB(255, 212, 212, 212), width:1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '차량 데이터 송수신 시뮬레이터',
                    style: TextStyle(fontWeight:FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Vehicle Data Transmission Simulator',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () async {
              setState(() {
                _isSending = !_isSending;
                _showBottomState = !_showBottomState;
              });

              if (_isSending) {
                final data = DataCache.instance.last;
                if (data != null && data.isNotEmpty) {
                  SimulatorBus.instance.pushData(data);
                }
              }
              setState(() => _isSending = false);
            },
            icon: Icon(Icons.send_rounded, color: Colors.white, size: 13),
            label: Text('전송', style:const TextStyle(color:Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataTabBar() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.only(bottom:12, left: 12, right: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
          
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'CAN 데이터'),
          Tab(text: 'OBD 데이터'),
        ],
      ),

    );
  }

  Widget _showState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.only(bottom:12, left: 12, right: 12),
      decoration: BoxDecoration(
        border: Border.all(color:const Color.fromARGB(255, 212, 212, 212), width:1.0),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0,3),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, color: Colors.green, size: 10,),
          SizedBox(width: 8,),
          Text('데이터 전송 중... (1초 간격)'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _header(),
          _dataTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CanDataPage(),
                ObdDataPage(),
              ],
            ),
          ),
          if (_showBottomState) _showState(),
        ],
      ),
    );
  }
}
