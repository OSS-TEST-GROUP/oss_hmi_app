//
//  Generated code. Do not modify.
//  source: agl_shell.proto
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

import 'agl_shell.pb.dart' as $0;

export 'agl_shell.pb.dart';

@$pb.GrpcServiceName('agl_shell_ipc.AglShellManagerService')
class AglShellManagerServiceClient extends $grpc.Client {
  static final _$activateApp = $grpc.ClientMethod<$0.ActivateRequest, $0.ActivateResponse>(
      '/agl_shell_ipc.AglShellManagerService/ActivateApp',
      ($0.ActivateRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ActivateResponse.fromBuffer(value));

  AglShellManagerServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.ActivateResponse> activateApp($0.ActivateRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$activateApp, request, options: options);
  }
}

@$pb.GrpcServiceName('agl_shell_ipc.AglShellManagerService')
abstract class AglShellManagerServiceBase extends $grpc.Service {
  $core.String get $name => 'agl_shell_ipc.AglShellManagerService';

  AglShellManagerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ActivateRequest, $0.ActivateResponse>(
        'ActivateApp',
        activateApp_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ActivateRequest.fromBuffer(value),
        ($0.ActivateResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ActivateResponse> activateApp_Pre($grpc.ServiceCall call, $async.Future<$0.ActivateRequest> request) async {
    return activateApp(call, await request);
  }

  $async.Future<$0.ActivateResponse> activateApp($grpc.ServiceCall call, $0.ActivateRequest request);
}
