import 'package:flutter/material.dart';
import 'package:vehicle_data_test/pages/can_data_page.dart';
import 'package:vehicle_data_test/pages/obd_data_page.dart';
import 'package:vehicle_data_test/grpc/grpc_server.dart';
import 'package:vehicle_data_test/grpc/grpc_client.dart';
import 'package:vehicle_data_test/pages/receiver_page.dart';
import 'package:vehicle_data_test/services/csv_loader.dart';
import 'package:vehicle_data_test/services/csv_playback.dart';

final grpcClient = GrpcClient(
  host: '127.0.0.1',
  port: 50052,
  path: '*',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 서버를 백그라운드로 시작 (UI 블로킹 방지)
  try {
    await GrpcServer.instance.start(port: 50052, address: '0.0.0.0');
    debugPrint('[main] start() returned');
    //await grpcClient.connect();
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
  String? _loadedFileName;
  int? _cIndex;
  int? _tRows;
  CsvTable? _table;

  late final TabController _tabController = TabController(length: 3, vsync: this);

  CsvPlayback? _playback;

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
        border: Border.all(color:const Color.fromARGB(255, 228, 228, 228), width:1.0),
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
          Row(
            children: [
              if (_loadedFileName != null)
               Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  '$_loadedFileName ($_cIndex/$_tRows)',
                  style: const TextStyle(color: Colors.grey),
                ),),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    
                    final picked = await CsvLoader.pickAndParse();
                    if (picked == null) return;
                
                    setState(() {
                      _table = picked;
                      _loadedFileName = picked.fileName;
                      _tRows = picked.rows.length;
                      _playback?.stop();
                      _playback = CsvPlayback(_table!, useSiUnits: false);
                      _cIndex = _playback?.currentIndex;
                      _isSending = false;
                    });
                
                  },
                  icon: Icon(Icons.open_in_new, color: Colors.white),
                  label: Text('LOAD CSV', style:const TextStyle(color:Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_table == null) return;
                    if (_playback == null) {
                      _playback = CsvPlayback(_table!, useSiUnits: false);
                    }

                    if (_isSending) {
                      _playback!.stop();
                      setState(() {
                        _isSending = false;
                        _cIndex = _playback?.currentIndex;
                      });
                    } else {
                      _playback!.start(interval: const Duration(seconds: 1));
                      setState(() {
                        _isSending = true;
                        _cIndex = _playback?.currentIndex;
                      });
                    }
                  },
                  icon: Icon(_isSending ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(_isSending ? 'PAUSE' : 'START', style:const TextStyle(color:Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSending ? Colors.red : Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _playback?.stop();
                  _playback?.reset();
                  setState(() {
                    _isSending = false;
                    _cIndex = _playback?.currentIndex;
                  });
                }, 
                icon: Icon(Icons.replay, color: Colors.white),
                label: Text('RESET', style:const TextStyle(color:Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 107, 107, 107),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataTabBar() {
    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(5),
        margin: const EdgeInsets.only(bottom:12, left: 12, right: 12),
        decoration: BoxDecoration(
          border: Border.all(color:Color.fromARGB(255, 228, 228, 228), width:1.0),
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
        child: TabBar(
          dividerColor: Colors.white,
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'TAB1'),
            Tab(text: 'TAB2'),
            Tab(text: '수신 데이터'),
          ],
        ),
      
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _header(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    CanDataPage(),
                    ObdDataPage(),
                    ReceiverPage(cloud: grpcClient),
                  ],
                ),
              ),
            //if (_showBottomState) _showState(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: _dataTabBar(),
          ),
        ]
      ),
    );
  }
}
