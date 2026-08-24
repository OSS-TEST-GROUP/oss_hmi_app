import 'dart:isolate';
import 'package:grpc/grpc.dart';
import '../src/generated/helloworld.pbgrpc.dart';

class GrpcIsolate {
  late Isolate _isolate;
  late SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  Future<void> init() async {
    _isolate = await Isolate.spawn(_grpcEntry, _receivePort.sendPort);
    _sendPort = await _receivePort.first as SendPort;
  }

  void sendHello(String name, Function(String) onMessage) {
    final responsePort = ReceivePort();
    _sendPort.send({'cmd': 'sayHello', 'name': name, 'port': responsePort.sendPort});

    responsePort.listen((msg) {
      onMessage(msg);
    });
  }

  void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }
}

Future<void>_grpcEntry(SendPort mainSendPort) async {
  final port = ReceivePort();
  mainSendPort.send(port.sendPort);

  await for (final msg in port) {
    if (msg is Map && msg['cmd'] == 'sayHello') {
      final name = msg['name'] as String;
      final replyPort = msg['port'] as SendPort;
      try {
        final channel = ClientChannel(
          '127.0.0.1',
          port: 50051,
          options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
        );
        final stub = GreeterClient(channel);
        final response = await stub.sayHello(HelloRequest()..name = name);
        replyPort.send('!!!!---- Response: ${response.message}');
        await channel.shutdown();
      } catch (e, st) {
        replyPort.send('!!!!---- Error: $e\n$st');
      }
    }
  }
}