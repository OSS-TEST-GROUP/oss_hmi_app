import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:vehicle_data_app/src/generated/VISSv3.0.pbgrpc.dart';
import 'package:vehicle_data_app/services/sim_bus.dart';
import 'subscription_registry.dart';

class VissService extends VISSServiceBase {
  String _now() => DateTime.now().toUtc().toIso8601String();

  RegExp _globToRegexCI(String pattern) {
    final escaped = RegExp.escape(pattern).replaceAll(r'\*', '.*');
    return RegExp('^$escaped\$', caseSensitive: false);
  }

  @override
  Stream<SubscribeStreamMessage> subscribeRequest(
      ServiceCall call, SubscribeRequestMessage request) async* {
    final subId = 'sim-${DateTime.now().millisecondsSinceEpoch}';
    final md = call.clientMetadata ?? const <String, String>{};
    final clientLabel =
        md['x-client-id'] ?? md['user-agent'] ?? md[':authority'] ?? 'unknown';

    final pattern = request.path.isEmpty ? '*' : request.path;
    final re = _globToRegexCI(pattern);

    debugPrint('[SUB][REQ] subId=$subId '
        'client=$clientLabel '
        'path=${request.path} reqId=${request.requestId} ts=${_now()}');

    debugPrint('!!!!---- request 옴!! requestId: ${request.requestId}');

    GrpcServer.instance.subs
        .add(subId, client: clientLabel, pathPattern: pattern);

    try {
      // ACK
      yield SubscribeStreamMessage()
        ..mType = SubscribeResponseType.RESPONSE
        ..status = ResponseStatus.SUCCESS
        ..response = (SubscribeStreamMessage_SubscribeResponseMessage()
          ..subscriptionId = subId
          ..requestId = request.requestId
          ..ts = _now()
          ..authorization =
              request.hasAuthorization() ? request.authorization : '');

      // 직전 스냅샷 1회
      // final last = SimulatorBus.instance.lastPack;
      // if (last != null) {
      //   yield SubscribeStreamMessage()
      //     ..mType = SubscribeResponseType.EVENT
      //     ..status = ResponseStatus.SUCCESS
      //     ..event = (SubscribeStreamMessage_SubscribeEventMessage()
      //       ..subscriptionId = subId
      //       ..successResponse =
      //           (SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage()
      //             ..dataPack = last)
      //       ..ts = _now());
      // }

      int sent = 0;

      // 데이터 스트림 루프
      await for (final pack in SimulatorBus.instance.stream) {
        // 서버 내부에서 비활성화됐거나(= unsubscribe 처리) 클라이언트가 끊었으면 종료
        if (!GrpcServer.instance.subs.isActive(subId)) {
          debugPrint('[SUB][STOP by unsubscribe] subId=$subId sent=$sent');
          break;
        }
        if (call.isCanceled) {
          debugPrint('[SUB][CANCELLED by client] subId=$subId sent=$sent');
          break;
        }

        final filtered = DataPackages();
        for (final pkg in pack.data) {
          if (!re.hasMatch(pkg.path)) continue;
          final copy = DataPackages_DataPackage()..path = pkg.path;
          for (final p in pkg.dp) {
            copy.dp.add(DataPackages_DataPackage_DataPoint()
              ..value = p.value
              ..ts = p.ts);
          }
          filtered.data.add(copy);
        }
        if (filtered.data.isEmpty) continue;

        debugPrint('[TX] subId=$subId client=$clientLabel path=$pattern '
            'items=${filtered.data.length} ts=${_now()}');

        sent++;
        yield SubscribeStreamMessage()
          ..mType = SubscribeResponseType.EVENT
          ..status = ResponseStatus.SUCCESS
          ..event = (SubscribeStreamMessage_SubscribeEventMessage()
            ..subscriptionId = subId
            ..successResponse =
                (SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage()
                  ..dataPack = filtered)
            ..ts = _now());
      }
    } finally {
      // 스트림 종료 시 레지스트리에서 제거
      GrpcServer.instance.subs.remove(subId);
      debugPrint('[SUB][END] subId=$subId ts=${_now()}');
    }
  }

  @override
  Future<GetResponseMessage> getRequest(
      ServiceCall call, GetRequestMessage request) async {
    // debugPrint('!!!!---- getrequest 옴!!\n');
    // final resp = GetResponseMessage()
    //   ..status = ResponseStatus.SUCCESS
    //   ..ts = _now();

    // if (request.hasRequestId()) resp.requestId = request.requestId;
    // if (request.hasAuthorization()) resp.authorization = request.authorization;

    // resp.successResponse = (GetResponseMessage_SuccessResponseMessage()
    //   ..dataPack = DataPackages()); // 간단히 빈 DataPackages 반환

    // return resp;
    debugPrint(
        '!!!!---- getrequest 옴!! path=${request.path} reqId=${request.requestId}');

    final resp = GetResponseMessage()
      ..status = ResponseStatus.SUCCESS
      ..ts = _now();

    if (request.hasRequestId()) resp.requestId = request.requestId;
    if (request.hasAuthorization()) resp.authorization = request.authorization;

    // 1) 패턴 → 정규식
    final pattern = request.path.isEmpty ? '*' : request.path;
    final re = _globToRegexCI(pattern);

    // 2) 시뮬레이터에서 마지막 스냅샷 하나 가져오기
    final last = SimulatorBus.instance.lastPack;

    final filtered = DataPackages();

    if (last != null) {
      for (final pkg in last.data) {
        if (!re.hasMatch(pkg.path)) continue;

        final copy = DataPackages_DataPackage()..path = pkg.path;
        for (final p in pkg.dp) {
          copy.dp.add(
            DataPackages_DataPackage_DataPoint()
              ..value = p.value
              ..ts = p.ts,
          );
        }
        if (copy.dp.isNotEmpty) {
          filtered.data.add(copy);
        }
      }
    }

    debugPrint('[GET] pattern=$pattern matched=${filtered.data.length} pkgs');

    resp.successResponse =
        (GetResponseMessage_SuccessResponseMessage()..dataPack = filtered);

    return resp;
  }

  @override
  Future<SetResponseMessage> setRequest(
      ServiceCall call, SetRequestMessage request) async {
    debugPrint('!!!!---- setrequest 옴!!\n');
    final resp = SetResponseMessage()
      ..status = ResponseStatus.SUCCESS // 단순 성공만 반환
      ..ts = _now();

    if (request.hasRequestId()) resp.requestId = request.requestId;
    if (request.hasAuthorization()) resp.authorization = request.authorization;

    return resp;
  }

  @override
  Future<UnsubscribeResponseMessage> unsubscribeRequest(
      ServiceCall call, UnsubscribeRequestMessage request) async {
    debugPrint('!!!!---- ubsubscribe request 옴!!\n');
    GrpcServer.instance.subs.cancel(request.subscriptionId);

    final resp = UnsubscribeResponseMessage()
      ..status = ResponseStatus.SUCCESS
      ..ts = _now();

    if (request.hasRequestId()) resp.requestId = request.requestId;

    debugPrint(
        '[UNSUB] subId=${request.subscriptionId} reqId=${request.requestId}');
    return resp;
  }
}

class GrpcServer {
  GrpcServer._();
  static final GrpcServer instance = GrpcServer._();

  final subs = SubscriptionRegistry();

  Server? _server;
  bool get isRunning => _server != null;

  Future<void> start({int port = 50051, String address = '0.0.0.0'}) async {
    if (_server != null) {
      debugPrint('[gRPC] start() skipped: already running');
      return;
    }

    try {
      _server = Server.create(
        services: [VissService()],
        //interceptors: const <ServerInterceptor>[],
        codecRegistry: CodecRegistry(
          codecs: [const GzipCodec(), const IdentityCodec()],
        ),
      );

      await _server!.serve(address: address, port: port);
      debugPrint('[gRPC] server started on $address:$port');
    } catch (e) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    debugPrint('[grpc] stop() called.');
    final s = _server;
    _server = null;
    SimulatorBus.instance.close();
    if (s != null) {
      debugPrint('this is stop() if');
      await s.shutdown();
      // ignore: avoid_print
      print('gRPC server stopped');
    } else {
      debugPrint('[grpc] server is already null.');
    }
  }
}
