import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:vehicle_data_app/grpc/grpc_server.dart';
import 'package:vehicle_data_app/services/sim_bus.dart';
import 'package:vehicle_data_app/src/generated/VISSv3.0.pbgrpc.dart';

class FakeServiceCall implements ServiceCall {
  @override
  final Map<String, String> clientMetadata = {'x-client-id': 'test-client'};

  @override
  bool get isCanceled => false;

  @override
  X509Certificate? get clientCertificate => null;

  @override
  DateTime? get deadline => null;

  @override
  Map<String, String>? get headers => null;

  @override
  bool get isTimedOut => false;

  @override
  InternetAddress? get remoteAddress => null;

  @override
  void sendHeaders() {}

  @override
  void sendTrailers({int? status, String? message}) {}

  @override
  Map<String, String>? get trailers => null;
}

void main() {
  group('VissService & GrpcServer Tests', () {
    late VissService service;
    late FakeServiceCall fakeCall;

    setUp(() {
      service = VissService();
      fakeCall = FakeServiceCall();
    });

    test('getRequest returns matched data points', () async {
      SimulatorBus.instance.pushData({
        'Vehicle.Speed': 88.0,
        'Vehicle.Powertrain.CombustionEngine.Speed': 3200,
      });

      final req = GetRequestMessage()
        ..path = 'Vehicle.Speed'
        ..requestId = 'req-101'
        ..authorization = 'token-123';

      final resp = await service.getRequest(fakeCall, req);

      expect(resp.status, ResponseStatus.SUCCESS);
      expect(resp.requestId, 'req-101');
      expect(resp.authorization, 'token-123');
      expect(resp.hasSuccessResponse(), isTrue);
      expect(resp.successResponse.dataPack.data.length, 1);
      expect(resp.successResponse.dataPack.data.first.path, 'Vehicle.Speed');
    });

    test('setRequest returns success status', () async {
      final req = SetRequestMessage()
        ..path = 'Vehicle.Speed'
        ..requestId = 'req-set-1'
        ..authorization = 'auth-token';

      final resp = await service.setRequest(fakeCall, req);
      expect(resp.status, ResponseStatus.SUCCESS);
      expect(resp.requestId, 'req-set-1');
      expect(resp.authorization, 'auth-token');
    });

    test('unsubscribeRequest cancels active subscription', () async {
      GrpcServer.instance.subs.add('sub-99', client: 'test', pathPattern: '*');
      expect(GrpcServer.instance.subs.isActive('sub-99'), isTrue);

      final req = UnsubscribeRequestMessage()
        ..subscriptionId = 'sub-99'
        ..requestId = 'unsub-1';

      final resp = await service.unsubscribeRequest(fakeCall, req);
      expect(resp.status, ResponseStatus.SUCCESS);
      expect(resp.requestId, 'unsub-1');
      expect(GrpcServer.instance.subs.isActive('sub-99'), isFalse);
    });

    test('subscribeRequest emits ACK and stream data', () async {
      final req = SubscribeRequestMessage()
        ..path = 'Vehicle.*'
        ..requestId = 'sub-req-1';

      final stream = service.subscribeRequest(fakeCall, req);
      final received = <SubscribeStreamMessage>[];
      final completer = Completer<void>();

      final sub = stream.listen((msg) {
        received.add(msg);
        if (received.length >= 2 && !completer.isCompleted) {
          completer.complete();
        }
      });

      // Allow ACK to be emitted
      await Future.delayed(const Duration(milliseconds: 50));
      SimulatorBus.instance.pushData({'Vehicle.Speed': 50.0});

      await completer.future.timeout(const Duration(seconds: 3));

      expect(received.first.mType, SubscribeResponseType.RESPONSE);
      expect(received.first.response.requestId, 'sub-req-1');
      expect(received[1].mType, SubscribeResponseType.EVENT);
      expect(received[1].event.successResponse.dataPack.data.first.path, 'Vehicle.Speed');

      await sub.cancel();
    });
  });
}
