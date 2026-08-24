import 'package:flutter/material.dart';
import 'package:vehicle_data_app/grpc/grpc_server.dart';
import 'package:vehicle_data_app/grpc/grpc_client.dart';
import 'package:vehicle_data_app/pages/receiver_page.dart';

final grpcClient = GrpcClient(
  host: '127.0.0.1',
  port: 50052, //default 5443
  path: '*',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 서버를 백그라운드로 시작 (UI 블로킹 방지)
  try {
    await GrpcServer.instance.start(port: 50052, address: '0.0.0.0');
    debugPrint('[main] start() returned');
  } catch (e) {
    // ignore: avoid_print
    print('Failed to start gRPC server: $e');
  }
  runApp(const VehicleDataApp());
}

class VehicleDataApp extends StatelessWidget {
  const VehicleDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Data App',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 245, 251, 253),
      ),
      home: const VehicleDataViewPage(),
    );
  }
}

/// hmi_launcher 등 외부 임베딩에서도 사용하는 메인 수신 데이터 뷰 페이지
class VehicleDataViewPage extends StatelessWidget {
  const VehicleDataViewPage({super.key, GrpcClient? client})
      : _client = client;

  final GrpcClient? _client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReceiverPage(cloud: _client ?? grpcClient),
    );
  }
}

