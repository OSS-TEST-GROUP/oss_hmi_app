//
//  Generated code. Do not modify.
//  source: VISSv3.0.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'VISSv3.0.pb.dart' as $0;

export 'VISSv3.0.pb.dart';

@$pb.GrpcServiceName('grpcProtobufMessages.VISS')
class VISSClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  static final _$getRequest =
      $grpc.ClientMethod<$0.GetRequestMessage, $0.GetResponseMessage>(
          '/grpcProtobufMessages.VISS/GetRequest',
          ($0.GetRequestMessage value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.GetResponseMessage.fromBuffer(value));
  static final _$setRequest =
      $grpc.ClientMethod<$0.SetRequestMessage, $0.SetResponseMessage>(
          '/grpcProtobufMessages.VISS/SetRequest',
          ($0.SetRequestMessage value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SetResponseMessage.fromBuffer(value));
  static final _$subscribeRequest =
      $grpc.ClientMethod<$0.SubscribeRequestMessage, $0.SubscribeStreamMessage>(
          '/grpcProtobufMessages.VISS/SubscribeRequest',
          ($0.SubscribeRequestMessage value) => value.writeToBuffer(),
          ($core.List<$core.int> value) =>
              $0.SubscribeStreamMessage.fromBuffer(value));
  static final _$unsubscribeRequest = $grpc.ClientMethod<
          $0.UnsubscribeRequestMessage, $0.UnsubscribeResponseMessage>(
      '/grpcProtobufMessages.VISS/UnsubscribeRequest',
      ($0.UnsubscribeRequestMessage value) => value.writeToBuffer(),
      ($core.List<$core.int> value) =>
          $0.UnsubscribeResponseMessage.fromBuffer(value));

  VISSClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.GetResponseMessage> getRequest(
      $0.GetRequestMessage request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getRequest, request, options: options);
  }

  $grpc.ResponseFuture<$0.SetResponseMessage> setRequest(
      $0.SetRequestMessage request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$setRequest, request, options: options);
  }

  $grpc.ResponseStream<$0.SubscribeStreamMessage> subscribeRequest(
      $0.SubscribeRequestMessage request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(
        _$subscribeRequest, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.UnsubscribeResponseMessage> unsubscribeRequest(
      $0.UnsubscribeRequestMessage request,
      {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$unsubscribeRequest, request, options: options);
  }
}

@$pb.GrpcServiceName('grpcProtobufMessages.VISS')
abstract class VISSServiceBase extends $grpc.Service {
  $core.String get $name => 'grpcProtobufMessages.VISS';

  VISSServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetRequestMessage, $0.GetResponseMessage>(
        'GetRequest',
        getRequest_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetRequestMessage.fromBuffer(value),
        ($0.GetResponseMessage value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetRequestMessage, $0.SetResponseMessage>(
        'SetRequest',
        setRequest_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SetRequestMessage.fromBuffer(value),
        ($0.SetResponseMessage value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SubscribeRequestMessage,
            $0.SubscribeStreamMessage>(
        'SubscribeRequest',
        subscribeRequest_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.SubscribeRequestMessage.fromBuffer(value),
        ($0.SubscribeStreamMessage value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UnsubscribeRequestMessage,
            $0.UnsubscribeResponseMessage>(
        'UnsubscribeRequest',
        unsubscribeRequest_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UnsubscribeRequestMessage.fromBuffer(value),
        ($0.UnsubscribeResponseMessage value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetResponseMessage> getRequest_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetRequestMessage> $request) async {
    return getRequest($call, await $request);
  }

  $async.Future<$0.SetResponseMessage> setRequest_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SetRequestMessage> $request) async {
    return setRequest($call, await $request);
  }

  $async.Stream<$0.SubscribeStreamMessage> subscribeRequest_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SubscribeRequestMessage> $request) async* {
    yield* subscribeRequest($call, await $request);
  }

  $async.Future<$0.UnsubscribeResponseMessage> unsubscribeRequest_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UnsubscribeRequestMessage> $request) async {
    return unsubscribeRequest($call, await $request);
  }

  $async.Future<$0.GetResponseMessage> getRequest(
      $grpc.ServiceCall call, $0.GetRequestMessage request);
  $async.Future<$0.SetResponseMessage> setRequest(
      $grpc.ServiceCall call, $0.SetRequestMessage request);
  $async.Stream<$0.SubscribeStreamMessage> subscribeRequest(
      $grpc.ServiceCall call, $0.SubscribeRequestMessage request);
  $async.Future<$0.UnsubscribeResponseMessage> unsubscribeRequest(
      $grpc.ServiceCall call, $0.UnsubscribeRequestMessage request);
}
