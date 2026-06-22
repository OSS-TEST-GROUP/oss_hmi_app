//
//  Generated code. Do not modify.
//  source: speech.proto
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

import 'common.pb.dart' as $1;
import 'speech.pb.dart' as $0;

export 'speech.pb.dart';

@$pb.GrpcServiceName('oais.speech.v1.SpeechService')
class SpeechServiceClient extends $grpc.Client {
  static final _$listSpeechPipelines = $grpc.ClientMethod<$0.ListSpeechPipelinesRequest, $0.ListSpeechPipelinesResponse>(
      '/oais.speech.v1.SpeechService/ListSpeechPipelines',
      ($0.ListSpeechPipelinesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListSpeechPipelinesResponse.fromBuffer(value));
  static final _$transcribe = $grpc.ClientMethod<$0.TranscribeRequest, $0.TranscribeResponse>(
      '/oais.speech.v1.SpeechService/Transcribe',
      ($0.TranscribeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TranscribeResponse.fromBuffer(value));
  static final _$streamingTranscribe = $grpc.ClientMethod<$1.AudioChunk, $0.TranscribeEvent>(
      '/oais.speech.v1.SpeechService/StreamingTranscribe',
      ($1.AudioChunk value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TranscribeEvent.fromBuffer(value));
  static final _$synthesize = $grpc.ClientMethod<$0.SynthesizeRequest, $0.SynthesizeResponse>(
      '/oais.speech.v1.SpeechService/Synthesize',
      ($0.SynthesizeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SynthesizeResponse.fromBuffer(value));

  SpeechServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.ListSpeechPipelinesResponse> listSpeechPipelines($0.ListSpeechPipelinesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listSpeechPipelines, request, options: options);
  }

  $grpc.ResponseFuture<$0.TranscribeResponse> transcribe($0.TranscribeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$transcribe, request, options: options);
  }

  $grpc.ResponseStream<$0.TranscribeEvent> streamingTranscribe($async.Stream<$1.AudioChunk> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$streamingTranscribe, request, options: options);
  }

  $grpc.ResponseFuture<$0.SynthesizeResponse> synthesize($0.SynthesizeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$synthesize, request, options: options);
  }
}

@$pb.GrpcServiceName('oais.speech.v1.SpeechService')
abstract class SpeechServiceBase extends $grpc.Service {
  $core.String get $name => 'oais.speech.v1.SpeechService';

  SpeechServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ListSpeechPipelinesRequest, $0.ListSpeechPipelinesResponse>(
        'ListSpeechPipelines',
        listSpeechPipelines_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListSpeechPipelinesRequest.fromBuffer(value),
        ($0.ListSpeechPipelinesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TranscribeRequest, $0.TranscribeResponse>(
        'Transcribe',
        transcribe_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TranscribeRequest.fromBuffer(value),
        ($0.TranscribeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.AudioChunk, $0.TranscribeEvent>(
        'StreamingTranscribe',
        streamingTranscribe,
        true,
        true,
        ($core.List<$core.int> value) => $1.AudioChunk.fromBuffer(value),
        ($0.TranscribeEvent value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SynthesizeRequest, $0.SynthesizeResponse>(
        'Synthesize',
        synthesize_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SynthesizeRequest.fromBuffer(value),
        ($0.SynthesizeResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ListSpeechPipelinesResponse> listSpeechPipelines_Pre($grpc.ServiceCall call, $async.Future<$0.ListSpeechPipelinesRequest> request) async {
    return listSpeechPipelines(call, await request);
  }

  $async.Future<$0.TranscribeResponse> transcribe_Pre($grpc.ServiceCall call, $async.Future<$0.TranscribeRequest> request) async {
    return transcribe(call, await request);
  }

  $async.Future<$0.SynthesizeResponse> synthesize_Pre($grpc.ServiceCall call, $async.Future<$0.SynthesizeRequest> request) async {
    return synthesize(call, await request);
  }

  $async.Future<$0.ListSpeechPipelinesResponse> listSpeechPipelines($grpc.ServiceCall call, $0.ListSpeechPipelinesRequest request);
  $async.Future<$0.TranscribeResponse> transcribe($grpc.ServiceCall call, $0.TranscribeRequest request);
  $async.Stream<$0.TranscribeEvent> streamingTranscribe($grpc.ServiceCall call, $async.Stream<$1.AudioChunk> request);
  $async.Future<$0.SynthesizeResponse> synthesize($grpc.ServiceCall call, $0.SynthesizeRequest request);
}
