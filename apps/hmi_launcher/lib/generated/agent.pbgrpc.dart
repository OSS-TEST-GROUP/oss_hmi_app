//
//  Generated code. Do not modify.
//  source: agent.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'agent.pb.dart' as $0;

export 'agent.pb.dart';

@$pb.GrpcServiceName('ivi.agent.Agent')
class AgentClient extends $grpc.Client {
  static final _$submit = $grpc.ClientMethod<$0.AgentSubmitRequest, $0.AgentSubmitResponse>(
      '/ivi.agent.Agent/Submit',
      ($0.AgentSubmitRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.AgentSubmitResponse.fromBuffer(value));
  static final _$subscribe = $grpc.ClientMethod<$0.SubscribeRequest, $0.ProactiveCard>(
      '/ivi.agent.Agent/Subscribe',
      ($0.SubscribeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ProactiveCard.fromBuffer(value));

  AgentClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.AgentSubmitResponse> submit($0.AgentSubmitRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$submit, request, options: options);
  }

  $grpc.ResponseStream<$0.ProactiveCard> subscribe($0.SubscribeRequest request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$subscribe, $async.Stream.fromIterable([request]), options: options);
  }
}

@$pb.GrpcServiceName('ivi.agent.Agent')
abstract class AgentServiceBase extends $grpc.Service {
  $core.String get $name => 'ivi.agent.Agent';

  AgentServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.AgentSubmitRequest, $0.AgentSubmitResponse>(
        'Submit',
        submit_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AgentSubmitRequest.fromBuffer(value),
        ($0.AgentSubmitResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SubscribeRequest, $0.ProactiveCard>(
        'Subscribe',
        subscribe_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.SubscribeRequest.fromBuffer(value),
        ($0.ProactiveCard value) => value.writeToBuffer()));
  }

  $async.Future<$0.AgentSubmitResponse> submit_Pre($grpc.ServiceCall call, $async.Future<$0.AgentSubmitRequest> request) async {
    return submit(call, await request);
  }

  $async.Stream<$0.ProactiveCard> subscribe_Pre($grpc.ServiceCall call, $async.Future<$0.SubscribeRequest> request) async* {
    yield* subscribe(call, await request);
  }

  $async.Future<$0.AgentSubmitResponse> submit($grpc.ServiceCall call, $0.AgentSubmitRequest request);
  $async.Stream<$0.ProactiveCard> subscribe($grpc.ServiceCall call, $0.SubscribeRequest request);
}
