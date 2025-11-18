import 'package:grpc/grpc.dart';
import 'package:vehicle_data_test/src/generated/VISSv3.0.pbgrpc.dart';
import 'dart:async';

class GrpcClient {
  GrpcClient({
    required this.host,
    required this.port,
    this.path = 'Vehicle.*',
    this.metadata = const <String, String>{},
  });

  String host;
  int port;
  String path;
  final Map<String, String> metadata;

  ClientChannel? _channel;
  VISSClient? _stub;

  ResponseStream<SubscribeStreamMessage>? _stream;
  StreamSubscription<SubscribeStreamMessage>? _sub;
  String? _subscriptionId;

  bool get isConnected => _channel != null;
  // bool get isSubscribed => _subscriptionId != null;

  final _events = StreamController<DataPackages>.broadcast();
  Stream<DataPackages> get events => _events.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    _channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _stub = VISSClient(_channel!);
    print('[CLOUD] Connected to $host:$port');
    // await subscribe();
  }

  Future<void> connectTo({
    required String host,
    required int port,
    String? path,
  }) async {
    // 기존 구독 해제
    // if (isSubscribed) {
    //   await unsubscribe();
    // }
    // // 기존 채널 정리
    // if (_channel != null) {
    //   await _channel!.shutdown();
    //   _channel = null;
    //   _stub = null;
    // }

    // this.host = host;
    // this.port = port;
    // if (path != null) {
    //   this.path = path;
    // }

    // await connect();

    if (_channel != null) {
      await _channel!.shutdown();
      _channel = null;
      _stub = null;
    }

    this.host = host;
    this.port = port;
    if (path != null) {
      this.path = path;
    }

    await connect();

    // 연결 직후 현재 path로 한 번 Get 호출
    await fetchLatest(requestId: 'cloud-get-connect');
  }

  Future<void> changePath(String newPath) async {
    // path = newPath;
    // if (_stub == null) {
    //   // 아직 연결 안 됐으면, 그냥 path만 기억해두고 끝
    //   print('[CLOUD] Path set to $path (not connected yet)');
    //   return;
    // }
    // // 이미 subscribe 되어 있으면 다시 구독
    // if (isSubscribed) {
    //   await unsubscribe(requestId: 'cloud-unsub-repath');
    // }
    // await subscribe(requestId: 'cloud-sub-repath');

    path = newPath;
    if (_stub == null) {
      print('[CLOUD] Path set to $path (not connected yet)');
      return;
    }

    print('[CLOUD] Path changed to $path, fetching once via Get...');
    await fetchLatest(requestId: 'cloud-get-repath');
  }

  Future<void> disconnect() async {
    // await unsubscribe();
    await _channel?.shutdown();
    _channel = null;
    _stub = null;
    await _events.close();
    print('[CLOUD] Disconnected');
    // final ch = _channel;
    // _channel = null;
    // _stub = null;
    // if (ch != null) {
    //   await ch.shutdown();
    //   print('[CLOUD] Disconnected');
    // }
  }

  Future<void> fetchLatest({String requestId = 'cloud-get-latest'}) async {
    if (_stub == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    final req = GetRequestMessage()
      ..path = path
      ..requestId = requestId;

    final ctx = CallOptions(
      metadata: metadata.isNotEmpty ? metadata : null,
    );

    print('[CLOUD][GET] request path=$path reqId=$requestId');
    final resp = await _stub!.getRequest(req, options: ctx);

    print('[CLOUD][GET] status=${resp.status} reqId=${resp.requestId} ts=${resp.ts}');

    if (resp.hasSuccessResponse() && resp.successResponse.hasDataPack()) {
      final dp = resp.successResponse.dataPack;
      // 👉 UI에서 StreamBuilder로 받을 수 있도록 push
      _events.add(dp);
    } else if (resp.hasErrorResponse()) {
      final err = resp.errorResponse;
      print('[CLOUD][GET][ERROR] ${err.number} ${err.reason} ${err.description}');
    } else {
      print('[CLOUD][GET] No DataPack / No ErrorResponse');
    }
  }

  Future<void> subscribe({String requestId = 'cloud-sub-1'}) async {
    if (_stub == null) {
      throw StateError('Not connected. Call connect() first.');
    }
    if (_sub != null) {
      print('[CLOUD] Already subscribed. Unsubscribe first.');
      return;
    }

    final req = SubscribeRequestMessage()
      ..path = path
      ..requestId = requestId;

    final ctx = CallOptions(metadata: metadata.isNotEmpty ? metadata : null);
    _stream = _stub!.subscribeRequest(req, options: ctx);
    _sub = _stream!.listen(
      (msg) {
        switch (msg.mType) {
          case SubscribeResponseType.RESPONSE:
            if (msg.hasResponse()) {
              _subscriptionId = msg.response.subscriptionId;
              final rid = msg.response.requestId;
              final ts = msg.response.ts;
              print('[CLOUD][ACK] subId=$_subscriptionId reqId=$rid ts=$ts');
            }
            break;
          case SubscribeResponseType.EVENT:
            if (msg.hasEvent() && msg.event.hasSuccessResponse()) {
              final dp = msg.event.successResponse.dataPack;
              _events.add(dp);
              // final ts = msg.event.ts;
              // print('[CLOUD][EVENT] subId=${msg.event.subscriptionId} ts=$ts itemsitems=${dp.data.length}');
              // for (final pkg in dp.data) {
              //   final p = pkg.path;
              //   for (final point in pkg.dp) {
              //     print(' - $p = ${point.value} @ ${point.ts}');
              //   }
              // }
            } else if (msg.hasEvent() && msg.event.hasErrorResponse()) {
              final err = msg.event.errorResponse;
              print('[CLOUD][EVENT][ERROR] ${err.number} ${err.reason} ${err.description}');
            }
            break;
        }
      },
      onError: (e, st) {
        print('[CLOUD][STREAM][ERROR] $e');
      },
      onDone: () {
        print('[CLOUD][STREAM][DONE]');
        _cleanupStreamBindings();
      },
      cancelOnError: true,
    );

    print('[CLOUD] Subscribe requested: path=$path');
  }

  Future<void> unsubscribe({String requestId = 'cloud-unsub-1'}) async {
    if (_stub == null) return;
    final subId = _subscriptionId;
    if (subId == null) return;

    try {
      final ureq = UnsubscribeRequestMessage()
        ..subscriptionId = subId
        ..requestId = requestId;
      final resp = await _stub!.unsubscribeRequest(ureq);
      print('[CLOUD][UNSUB] status=${resp.status} reqId=${resp.requestId} ts=${resp.ts}');
    } catch (e) {
      print('[CLOUD][UNSUB][ERROR] $e');
    } finally {
      await _sub?.cancel();
      _cleanupStreamBindings();
    }
  }

  void _cleanupStreamBindings() {
    _sub = null;
    _stream = null;
    _subscriptionId = null;
  }

  Future<void> getOnce(String vssPath, {String requestId = 'cloud-get-1'}) async {
    if (_stub == null) throw StateError('Not connected.');
    final req = GetRequestMessage()
      ..path = vssPath
      ..requestId = requestId;
    final resp = await _stub!.getRequest(req);
    print('[CLOUD][GET] status=${resp.status} reqId=${resp.requestId} ts=${resp.ts}');
    if (resp.hasSuccessResponse() && resp.successResponse.hasDataPack()) {
      final dp = resp.successResponse.dataPack;
      _events.add(dp);
      for (final pkg in dp.data) {
        for (final p in pkg.dp) {
          print(' - ${pkg.path} = ${p.value} @ ${p.ts}');
        }
      }
    } else if (resp.hasErrorResponse()) {
      print('[CLOUD][GET][ERROR] ${resp.errorResponse.number} '
              '${resp.errorResponse.reason} ${resp.errorResponse.description}');
    }
  }
}