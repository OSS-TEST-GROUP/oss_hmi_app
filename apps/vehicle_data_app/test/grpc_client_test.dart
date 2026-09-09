import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_data_app/grpc/grpc_client.dart';
import 'package:vehicle_data_app/grpc/grpc_server.dart';
import 'package:vehicle_data_app/services/sim_bus.dart';
import 'package:vehicle_data_app/src/generated/VISSv3.0.pbgrpc.dart';

void main() {
  group('GrpcClient Tests', () {
    late GrpcClient client;
    const testPort = 50068;

    setUpAll(() async {
      await GrpcServer.instance.start(port: testPort);
    });

    tearDownAll(() async {
      await GrpcServer.instance.stop();
    });

    setUp(() {
      client = GrpcClient(host: '127.0.0.1', port: testPort, metadata: {'x-client': 'unit-test'});
    });

    tearDown(() async {
      await client.disconnect();
    });

    test('connect and isConnected property', () async {
      expect(client.isConnected, isFalse);
      await client.connect();
      expect(client.isConnected, isTrue);

      // Multiple connects are no-op
      await client.connect();
      expect(client.isConnected, isTrue);
    });

    test('connectTo reconnects with new host and port and fetches latest', () async {
      await client.connectTo(host: '127.0.0.1', port: testPort, path: 'Vehicle.Speed');
      expect(client.isConnected, isTrue);
      expect(client.path, 'Vehicle.Speed');
    });

    test('changePath updates path and fetches latest when connected', () async {
      final unconnClient = GrpcClient(host: '127.0.0.1', port: testPort);
      await unconnClient.changePath('Vehicle.OBD.Speed');
      expect(unconnClient.path, 'Vehicle.OBD.Speed');

      await client.connect();
      await client.changePath('Vehicle.CurrentLocation.*');
      expect(client.path, 'Vehicle.CurrentLocation.*');
    });

    test('fetchLatest and getOnce push data to events stream', () async {
      await client.connect();

      // Seed data in SimBus
      SimulatorBus.instance.pushData({
        'Vehicle.Speed': 85.5,
      });

      final received = <DataPackages>[];
      final sub = client.events.listen(received.add);

      await client.fetchLatest(requestId: 'test-get-1');
      await client.getOnce('Vehicle.Speed', requestId: 'test-get-2');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received, isNotEmpty);
      await sub.cancel();
    });

    test('subscribe and unsubscribe receive streaming events', () async {
      await client.connect();

      final received = <DataPackages>[];
      final sub = client.events.listen(received.add);

      await client.subscribe(requestId: 'test-sub-1');
      // Multiple subscribes are ignored
      await client.subscribe(requestId: 'test-sub-dup');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Push simulated data
      SimulatorBus.instance.pushData({
        'Vehicle.Speed': 90.0,
      });

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(received, isNotEmpty);

      await client.unsubscribe(requestId: 'test-unsub-1');
      await sub.cancel();
    });

    test('unconnected client throws StateError on fetchLatest/subscribe/getOnce', () async {
      final unconn = GrpcClient(host: '127.0.0.1', port: testPort);
      expect(() => unconn.fetchLatest(), throwsStateError);
      expect(() => unconn.subscribe(), throwsStateError);
      expect(() => unconn.getOnce('Vehicle.Speed'), throwsStateError);
    });
  });
}
