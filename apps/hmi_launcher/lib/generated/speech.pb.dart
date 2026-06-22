//
//  Generated code. Do not modify.
//  source: speech.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $1;

class SynthesizeRequest extends $pb.GeneratedMessage {
  factory SynthesizeRequest({
    $core.String? text,
    $core.String? locale,
    $core.String? pipelineId,
    $core.int? speakerId,
  }) {
    final $result = create();
    if (text != null) {
      $result.text = text;
    }
    if (locale != null) {
      $result.locale = locale;
    }
    if (pipelineId != null) {
      $result.pipelineId = pipelineId;
    }
    if (speakerId != null) {
      $result.speakerId = speakerId;
    }
    return $result;
  }
  SynthesizeRequest._() : super();
  factory SynthesizeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SynthesizeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SynthesizeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'locale')
    ..aOS(3, _omitFieldNames ? '' : 'pipelineId')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'speakerId', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SynthesizeRequest clone() => SynthesizeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SynthesizeRequest copyWith(void Function(SynthesizeRequest) updates) => super.copyWith((message) => updates(message as SynthesizeRequest)) as SynthesizeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SynthesizeRequest create() => SynthesizeRequest._();
  SynthesizeRequest createEmptyInstance() => create();
  static $pb.PbList<SynthesizeRequest> createRepeated() => $pb.PbList<SynthesizeRequest>();
  @$core.pragma('dart2js:noInline')
  static SynthesizeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SynthesizeRequest>(create);
  static SynthesizeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get locale => $_getSZ(1);
  @$pb.TagNumber(2)
  set locale($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLocale() => $_has(1);
  @$pb.TagNumber(2)
  void clearLocale() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get pipelineId => $_getSZ(2);
  @$pb.TagNumber(3)
  set pipelineId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPipelineId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPipelineId() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get speakerId => $_getIZ(3);
  @$pb.TagNumber(4)
  set speakerId($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSpeakerId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSpeakerId() => clearField(4);
}

class SynthesizeResponse extends $pb.GeneratedMessage {
  factory SynthesizeResponse({
    $core.bool? success,
    $core.List<$core.int>? audio,
    $core.int? sampleRateHz,
    $core.int? channels,
    $core.String? errorMessage,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (audio != null) {
      $result.audio = audio;
    }
    if (sampleRateHz != null) {
      $result.sampleRateHz = sampleRateHz;
    }
    if (channels != null) {
      $result.channels = channels;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    return $result;
  }
  SynthesizeResponse._() : super();
  factory SynthesizeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SynthesizeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SynthesizeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'audio', $pb.PbFieldType.OY)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'sampleRateHz', $pb.PbFieldType.OU3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'channels', $pb.PbFieldType.OU3)
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SynthesizeResponse clone() => SynthesizeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SynthesizeResponse copyWith(void Function(SynthesizeResponse) updates) => super.copyWith((message) => updates(message as SynthesizeResponse)) as SynthesizeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SynthesizeResponse create() => SynthesizeResponse._();
  SynthesizeResponse createEmptyInstance() => create();
  static $pb.PbList<SynthesizeResponse> createRepeated() => $pb.PbList<SynthesizeResponse>();
  @$core.pragma('dart2js:noInline')
  static SynthesizeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SynthesizeResponse>(create);
  static SynthesizeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get audio => $_getN(1);
  @$pb.TagNumber(2)
  set audio($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAudio() => $_has(1);
  @$pb.TagNumber(2)
  void clearAudio() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get sampleRateHz => $_getIZ(2);
  @$pb.TagNumber(3)
  set sampleRateHz($core.int v) { $_setUnsignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSampleRateHz() => $_has(2);
  @$pb.TagNumber(3)
  void clearSampleRateHz() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get channels => $_getIZ(3);
  @$pb.TagNumber(4)
  set channels($core.int v) { $_setUnsignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasChannels() => $_has(3);
  @$pb.TagNumber(4)
  void clearChannels() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => clearField(5);
}

class ListSpeechPipelinesRequest extends $pb.GeneratedMessage {
  factory ListSpeechPipelinesRequest() => create();
  ListSpeechPipelinesRequest._() : super();
  factory ListSpeechPipelinesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListSpeechPipelinesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListSpeechPipelinesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListSpeechPipelinesRequest clone() => ListSpeechPipelinesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListSpeechPipelinesRequest copyWith(void Function(ListSpeechPipelinesRequest) updates) => super.copyWith((message) => updates(message as ListSpeechPipelinesRequest)) as ListSpeechPipelinesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSpeechPipelinesRequest create() => ListSpeechPipelinesRequest._();
  ListSpeechPipelinesRequest createEmptyInstance() => create();
  static $pb.PbList<ListSpeechPipelinesRequest> createRepeated() => $pb.PbList<ListSpeechPipelinesRequest>();
  @$core.pragma('dart2js:noInline')
  static ListSpeechPipelinesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListSpeechPipelinesRequest>(create);
  static ListSpeechPipelinesRequest? _defaultInstance;
}

class ListSpeechPipelinesResponse extends $pb.GeneratedMessage {
  factory ListSpeechPipelinesResponse({
    $core.Iterable<$1.PipelineInfo>? pipelines,
  }) {
    final $result = create();
    if (pipelines != null) {
      $result.pipelines.addAll(pipelines);
    }
    return $result;
  }
  ListSpeechPipelinesResponse._() : super();
  factory ListSpeechPipelinesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListSpeechPipelinesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListSpeechPipelinesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..pc<$1.PipelineInfo>(1, _omitFieldNames ? '' : 'pipelines', $pb.PbFieldType.PM, subBuilder: $1.PipelineInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListSpeechPipelinesResponse clone() => ListSpeechPipelinesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListSpeechPipelinesResponse copyWith(void Function(ListSpeechPipelinesResponse) updates) => super.copyWith((message) => updates(message as ListSpeechPipelinesResponse)) as ListSpeechPipelinesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSpeechPipelinesResponse create() => ListSpeechPipelinesResponse._();
  ListSpeechPipelinesResponse createEmptyInstance() => create();
  static $pb.PbList<ListSpeechPipelinesResponse> createRepeated() => $pb.PbList<ListSpeechPipelinesResponse>();
  @$core.pragma('dart2js:noInline')
  static ListSpeechPipelinesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListSpeechPipelinesResponse>(create);
  static ListSpeechPipelinesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$1.PipelineInfo> get pipelines => $_getList(0);
}

///  -----------------------------------------------------------------------------
///  TranscribeRequest
///
///  Unary transcription. For continuous mic input, prefer StreamingTranscribe.
///  `enable_postprocess` toggles backend-specific normalization (punctuation,
///  inverse text normalization, etc.) if the pipeline supports it.
///  -----------------------------------------------------------------------------
class TranscribeRequest extends $pb.GeneratedMessage {
  factory TranscribeRequest({
    $core.String? pipelineId,
    $core.List<$core.int>? audio,
    $1.AudioFormat? format,
    $core.String? locale,
    $core.bool? enablePostprocess,
  }) {
    final $result = create();
    if (pipelineId != null) {
      $result.pipelineId = pipelineId;
    }
    if (audio != null) {
      $result.audio = audio;
    }
    if (format != null) {
      $result.format = format;
    }
    if (locale != null) {
      $result.locale = locale;
    }
    if (enablePostprocess != null) {
      $result.enablePostprocess = enablePostprocess;
    }
    return $result;
  }
  TranscribeRequest._() : super();
  factory TranscribeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TranscribeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TranscribeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pipelineId')
    ..a<$core.List<$core.int>>(2, _omitFieldNames ? '' : 'audio', $pb.PbFieldType.OY)
    ..aOM<$1.AudioFormat>(3, _omitFieldNames ? '' : 'format', subBuilder: $1.AudioFormat.create)
    ..aOS(4, _omitFieldNames ? '' : 'locale')
    ..aOB(5, _omitFieldNames ? '' : 'enablePostprocess')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TranscribeRequest clone() => TranscribeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TranscribeRequest copyWith(void Function(TranscribeRequest) updates) => super.copyWith((message) => updates(message as TranscribeRequest)) as TranscribeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TranscribeRequest create() => TranscribeRequest._();
  TranscribeRequest createEmptyInstance() => create();
  static $pb.PbList<TranscribeRequest> createRepeated() => $pb.PbList<TranscribeRequest>();
  @$core.pragma('dart2js:noInline')
  static TranscribeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TranscribeRequest>(create);
  static TranscribeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pipelineId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pipelineId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPipelineId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPipelineId() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get audio => $_getN(1);
  @$pb.TagNumber(2)
  set audio($core.List<$core.int> v) { $_setBytes(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAudio() => $_has(1);
  @$pb.TagNumber(2)
  void clearAudio() => clearField(2);

  @$pb.TagNumber(3)
  $1.AudioFormat get format => $_getN(2);
  @$pb.TagNumber(3)
  set format($1.AudioFormat v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormat() => clearField(3);
  @$pb.TagNumber(3)
  $1.AudioFormat ensureFormat() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get locale => $_getSZ(3);
  @$pb.TagNumber(4)
  set locale($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLocale() => $_has(3);
  @$pb.TagNumber(4)
  void clearLocale() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get enablePostprocess => $_getBF(4);
  @$pb.TagNumber(5)
  set enablePostprocess($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasEnablePostprocess() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnablePostprocess() => clearField(5);
}

class TranscribeResponse extends $pb.GeneratedMessage {
  factory TranscribeResponse({
    $core.bool? success,
    $core.String? transcript,
    $core.String? normalizedText,
    $core.String? errorMessage,
    $core.String? pipelineId,
    $1.MetricSet? metrics,
    $core.Map<$core.String, $core.String>? metadata,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (transcript != null) {
      $result.transcript = transcript;
    }
    if (normalizedText != null) {
      $result.normalizedText = normalizedText;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    if (pipelineId != null) {
      $result.pipelineId = pipelineId;
    }
    if (metrics != null) {
      $result.metrics = metrics;
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    return $result;
  }
  TranscribeResponse._() : super();
  factory TranscribeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TranscribeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TranscribeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'transcript')
    ..aOS(3, _omitFieldNames ? '' : 'normalizedText')
    ..aOS(4, _omitFieldNames ? '' : 'errorMessage')
    ..aOS(5, _omitFieldNames ? '' : 'pipelineId')
    ..aOM<$1.MetricSet>(6, _omitFieldNames ? '' : 'metrics', subBuilder: $1.MetricSet.create)
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'metadata', entryClassName: 'TranscribeResponse.MetadataEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('oais.speech.v1'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TranscribeResponse clone() => TranscribeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TranscribeResponse copyWith(void Function(TranscribeResponse) updates) => super.copyWith((message) => updates(message as TranscribeResponse)) as TranscribeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TranscribeResponse create() => TranscribeResponse._();
  TranscribeResponse createEmptyInstance() => create();
  static $pb.PbList<TranscribeResponse> createRepeated() => $pb.PbList<TranscribeResponse>();
  @$core.pragma('dart2js:noInline')
  static TranscribeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TranscribeResponse>(create);
  static TranscribeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get transcript => $_getSZ(1);
  @$pb.TagNumber(2)
  set transcript($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTranscript() => $_has(1);
  @$pb.TagNumber(2)
  void clearTranscript() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get normalizedText => $_getSZ(2);
  @$pb.TagNumber(3)
  set normalizedText($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasNormalizedText() => $_has(2);
  @$pb.TagNumber(3)
  void clearNormalizedText() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get errorMessage => $_getSZ(3);
  @$pb.TagNumber(4)
  set errorMessage($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasErrorMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearErrorMessage() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get pipelineId => $_getSZ(4);
  @$pb.TagNumber(5)
  set pipelineId($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPipelineId() => $_has(4);
  @$pb.TagNumber(5)
  void clearPipelineId() => clearField(5);

  @$pb.TagNumber(6)
  $1.MetricSet get metrics => $_getN(5);
  @$pb.TagNumber(6)
  set metrics($1.MetricSet v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasMetrics() => $_has(5);
  @$pb.TagNumber(6)
  void clearMetrics() => clearField(6);
  @$pb.TagNumber(6)
  $1.MetricSet ensureMetrics() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(6);
}

///  -----------------------------------------------------------------------------
///  TranscribeEvent
///
///  Streaming response frame. `is_final=false` events carry incremental
///  `partial` transcripts. The terminating event has `is_final=true` and
///  `final_text` populated.
///  -----------------------------------------------------------------------------
class TranscribeEvent extends $pb.GeneratedMessage {
  factory TranscribeEvent({
    $core.String? sessionId,
    $core.String? pipelineId,
    $core.bool? success,
    $core.String? partial,
    $core.String? finalText,
    $core.bool? isFinal,
    $core.String? errorMessage,
    $1.MetricSet? metrics,
  }) {
    final $result = create();
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    if (pipelineId != null) {
      $result.pipelineId = pipelineId;
    }
    if (success != null) {
      $result.success = success;
    }
    if (partial != null) {
      $result.partial = partial;
    }
    if (finalText != null) {
      $result.finalText = finalText;
    }
    if (isFinal != null) {
      $result.isFinal = isFinal;
    }
    if (errorMessage != null) {
      $result.errorMessage = errorMessage;
    }
    if (metrics != null) {
      $result.metrics = metrics;
    }
    return $result;
  }
  TranscribeEvent._() : super();
  factory TranscribeEvent.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TranscribeEvent.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TranscribeEvent', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.speech.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'pipelineId')
    ..aOB(3, _omitFieldNames ? '' : 'success')
    ..aOS(4, _omitFieldNames ? '' : 'partial')
    ..aOS(5, _omitFieldNames ? '' : 'finalText')
    ..aOB(6, _omitFieldNames ? '' : 'isFinal')
    ..aOS(7, _omitFieldNames ? '' : 'errorMessage')
    ..aOM<$1.MetricSet>(8, _omitFieldNames ? '' : 'metrics', subBuilder: $1.MetricSet.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TranscribeEvent clone() => TranscribeEvent()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TranscribeEvent copyWith(void Function(TranscribeEvent) updates) => super.copyWith((message) => updates(message as TranscribeEvent)) as TranscribeEvent;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TranscribeEvent create() => TranscribeEvent._();
  TranscribeEvent createEmptyInstance() => create();
  static $pb.PbList<TranscribeEvent> createRepeated() => $pb.PbList<TranscribeEvent>();
  @$core.pragma('dart2js:noInline')
  static TranscribeEvent getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TranscribeEvent>(create);
  static TranscribeEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get pipelineId => $_getSZ(1);
  @$pb.TagNumber(2)
  set pipelineId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPipelineId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPipelineId() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get success => $_getBF(2);
  @$pb.TagNumber(3)
  set success($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSuccess() => $_has(2);
  @$pb.TagNumber(3)
  void clearSuccess() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get partial => $_getSZ(3);
  @$pb.TagNumber(4)
  set partial($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPartial() => $_has(3);
  @$pb.TagNumber(4)
  void clearPartial() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get finalText => $_getSZ(4);
  @$pb.TagNumber(5)
  set finalText($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasFinalText() => $_has(4);
  @$pb.TagNumber(5)
  void clearFinalText() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isFinal => $_getBF(5);
  @$pb.TagNumber(6)
  set isFinal($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsFinal() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsFinal() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get errorMessage => $_getSZ(6);
  @$pb.TagNumber(7)
  set errorMessage($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasErrorMessage() => $_has(6);
  @$pb.TagNumber(7)
  void clearErrorMessage() => clearField(7);

  @$pb.TagNumber(8)
  $1.MetricSet get metrics => $_getN(7);
  @$pb.TagNumber(8)
  set metrics($1.MetricSet v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasMetrics() => $_has(7);
  @$pb.TagNumber(8)
  void clearMetrics() => clearField(8);
  @$pb.TagNumber(8)
  $1.MetricSet ensureMetrics() => $_ensure(7);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
