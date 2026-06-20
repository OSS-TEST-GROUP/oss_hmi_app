//
//  Generated code. Do not modify.
//  source: common.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pbenum.dart';

export 'common.pbenum.dart';

///  -----------------------------------------------------------------------------
///  MetricSet
///
///  Per-stage timing breakdown carried by every response. A given service only
///  fills the fields that apply to its pipeline; the rest stay 0.
///
///    speech  : stt_ms, total_ms
///    command : router_ms, llm_ttft_ms, llm_ms, tool_ms, safety_ms, total_ms
///              perceived_ms (router_ms in fast paths)
///    voice   : all of the above (stt + command stages combined)
///
///  Adding a new stage = add a new field at the end. Never repurpose existing
///  numbers.
///  -----------------------------------------------------------------------------
class MetricSet extends $pb.GeneratedMessage {
  factory MetricSet({
    $core.double? sttMs,
    $core.double? routerMs,
    $core.double? llmTtftMs,
    $core.double? llmMs,
    $core.double? toolMs,
    $core.double? safetyMs,
    $core.double? perceivedMs,
    $core.double? totalMs,
  }) {
    final $result = create();
    if (sttMs != null) {
      $result.sttMs = sttMs;
    }
    if (routerMs != null) {
      $result.routerMs = routerMs;
    }
    if (llmTtftMs != null) {
      $result.llmTtftMs = llmTtftMs;
    }
    if (llmMs != null) {
      $result.llmMs = llmMs;
    }
    if (toolMs != null) {
      $result.toolMs = toolMs;
    }
    if (safetyMs != null) {
      $result.safetyMs = safetyMs;
    }
    if (perceivedMs != null) {
      $result.perceivedMs = perceivedMs;
    }
    if (totalMs != null) {
      $result.totalMs = totalMs;
    }
    return $result;
  }
  MetricSet._() : super();
  factory MetricSet.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MetricSet.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MetricSet', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.common.v1'), createEmptyInstance: create)
    ..a<$core.double>(1, _omitFieldNames ? '' : 'sttMs', $pb.PbFieldType.OD)
    ..a<$core.double>(2, _omitFieldNames ? '' : 'routerMs', $pb.PbFieldType.OD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'llmTtftMs', $pb.PbFieldType.OD)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'llmMs', $pb.PbFieldType.OD)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'toolMs', $pb.PbFieldType.OD)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'safetyMs', $pb.PbFieldType.OD)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'perceivedMs', $pb.PbFieldType.OD)
    ..a<$core.double>(8, _omitFieldNames ? '' : 'totalMs', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MetricSet clone() => MetricSet()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MetricSet copyWith(void Function(MetricSet) updates) => super.copyWith((message) => updates(message as MetricSet)) as MetricSet;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetricSet create() => MetricSet._();
  MetricSet createEmptyInstance() => create();
  static $pb.PbList<MetricSet> createRepeated() => $pb.PbList<MetricSet>();
  @$core.pragma('dart2js:noInline')
  static MetricSet getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MetricSet>(create);
  static MetricSet? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get sttMs => $_getN(0);
  @$pb.TagNumber(1)
  set sttMs($core.double v) { $_setDouble(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSttMs() => $_has(0);
  @$pb.TagNumber(1)
  void clearSttMs() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get routerMs => $_getN(1);
  @$pb.TagNumber(2)
  set routerMs($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRouterMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearRouterMs() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get llmTtftMs => $_getN(2);
  @$pb.TagNumber(3)
  set llmTtftMs($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasLlmTtftMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearLlmTtftMs() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get llmMs => $_getN(3);
  @$pb.TagNumber(4)
  set llmMs($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLlmMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearLlmMs() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get toolMs => $_getN(4);
  @$pb.TagNumber(5)
  set toolMs($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasToolMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearToolMs() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get safetyMs => $_getN(5);
  @$pb.TagNumber(6)
  set safetyMs($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasSafetyMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearSafetyMs() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get perceivedMs => $_getN(6);
  @$pb.TagNumber(7)
  set perceivedMs($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasPerceivedMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearPerceivedMs() => clearField(7);

  @$pb.TagNumber(8)
  $core.double get totalMs => $_getN(7);
  @$pb.TagNumber(8)
  set totalMs($core.double v) { $_setDouble(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasTotalMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalMs() => clearField(8);
}

///  -----------------------------------------------------------------------------
///  PipelineInfo
///
///  Returned by ListSpeechPipelines / ListCommandPipelines / ListVoicePipelines.
///  `kind` distinguishes which service owns the pipeline ("speech" / "command"
///  / "voice"). `metadata` is intentionally free-form so clients can opt into
///  new capabilities without breaking the wire contract.
///  -----------------------------------------------------------------------------
class PipelineInfo extends $pb.GeneratedMessage {
  factory PipelineInfo({
    $core.String? id,
    $core.String? kind,
    $core.String? description,
    $core.Iterable<$core.String>? tags,
    $core.Map<$core.String, $core.String>? metadata,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (kind != null) {
      $result.kind = kind;
    }
    if (description != null) {
      $result.description = description;
    }
    if (tags != null) {
      $result.tags.addAll(tags);
    }
    if (metadata != null) {
      $result.metadata.addAll(metadata);
    }
    return $result;
  }
  PipelineInfo._() : super();
  factory PipelineInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PipelineInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PipelineInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.common.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..pPS(4, _omitFieldNames ? '' : 'tags')
    ..m<$core.String, $core.String>(5, _omitFieldNames ? '' : 'metadata', entryClassName: 'PipelineInfo.MetadataEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('oais.common.v1'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PipelineInfo clone() => PipelineInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PipelineInfo copyWith(void Function(PipelineInfo) updates) => super.copyWith((message) => updates(message as PipelineInfo)) as PipelineInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PipelineInfo create() => PipelineInfo._();
  PipelineInfo createEmptyInstance() => create();
  static $pb.PbList<PipelineInfo> createRepeated() => $pb.PbList<PipelineInfo>();
  @$core.pragma('dart2js:noInline')
  static PipelineInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PipelineInfo>(create);
  static PipelineInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.String> get tags => $_getList(3);

  @$pb.TagNumber(5)
  $core.Map<$core.String, $core.String> get metadata => $_getMap(4);
}

///  -----------------------------------------------------------------------------
///  AudioFormat
///
///  Encoding is a string (e.g. "pcm_s16le", "wav") rather than enum so callers
///  can ship new formats without proto regeneration. Servers reject unknown
///  encodings explicitly.
///  -----------------------------------------------------------------------------
class AudioFormat extends $pb.GeneratedMessage {
  factory AudioFormat({
    $core.int? sampleRateHz,
    $core.int? channels,
    $core.String? encoding,
  }) {
    final $result = create();
    if (sampleRateHz != null) {
      $result.sampleRateHz = sampleRateHz;
    }
    if (channels != null) {
      $result.channels = channels;
    }
    if (encoding != null) {
      $result.encoding = encoding;
    }
    return $result;
  }
  AudioFormat._() : super();
  factory AudioFormat.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AudioFormat.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AudioFormat', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.common.v1'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'sampleRateHz', $pb.PbFieldType.OU3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'channels', $pb.PbFieldType.OU3)
    ..aOS(3, _omitFieldNames ? '' : 'encoding')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AudioFormat clone() => AudioFormat()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AudioFormat copyWith(void Function(AudioFormat) updates) => super.copyWith((message) => updates(message as AudioFormat)) as AudioFormat;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AudioFormat create() => AudioFormat._();
  AudioFormat createEmptyInstance() => create();
  static $pb.PbList<AudioFormat> createRepeated() => $pb.PbList<AudioFormat>();
  @$core.pragma('dart2js:noInline')
  static AudioFormat getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AudioFormat>(create);
  static AudioFormat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get sampleRateHz => $_getIZ(0);
  @$pb.TagNumber(1)
  set sampleRateHz($core.int v) { $_setUnsignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSampleRateHz() => $_has(0);
  @$pb.TagNumber(1)
  void clearSampleRateHz() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get channels => $_getIZ(1);
  @$pb.TagNumber(2)
  set channels($core.int v) { $_setUnsignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasChannels() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannels() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get encoding => $_getSZ(2);
  @$pb.TagNumber(3)
  set encoding($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasEncoding() => $_has(2);
  @$pb.TagNumber(3)
  void clearEncoding() => clearField(3);
}

///  -----------------------------------------------------------------------------
///  AudioChunk
///
///  Streaming-side input frame for SpeechService.StreamingTranscribe and
///  VoiceService.StreamingVoiceCommand. The first chunk per session must set
///  `pipeline_id` and `format`; subsequent chunks may omit them. The final
///  chunk MUST set `end_of_stream=true` so the server can flush the decoder.
///  -----------------------------------------------------------------------------
class AudioChunk extends $pb.GeneratedMessage {
  factory AudioChunk({
    $core.String? sessionId,
    $core.String? pipelineId,
    AudioFormat? format,
    $core.List<$core.int>? audio,
    $core.bool? endOfStream,
  }) {
    final $result = create();
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    if (pipelineId != null) {
      $result.pipelineId = pipelineId;
    }
    if (format != null) {
      $result.format = format;
    }
    if (audio != null) {
      $result.audio = audio;
    }
    if (endOfStream != null) {
      $result.endOfStream = endOfStream;
    }
    return $result;
  }
  AudioChunk._() : super();
  factory AudioChunk.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AudioChunk.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AudioChunk', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.common.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'pipelineId')
    ..aOM<AudioFormat>(3, _omitFieldNames ? '' : 'format', subBuilder: AudioFormat.create)
    ..a<$core.List<$core.int>>(4, _omitFieldNames ? '' : 'audio', $pb.PbFieldType.OY)
    ..aOB(5, _omitFieldNames ? '' : 'endOfStream')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AudioChunk clone() => AudioChunk()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AudioChunk copyWith(void Function(AudioChunk) updates) => super.copyWith((message) => updates(message as AudioChunk)) as AudioChunk;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AudioChunk create() => AudioChunk._();
  AudioChunk createEmptyInstance() => create();
  static $pb.PbList<AudioChunk> createRepeated() => $pb.PbList<AudioChunk>();
  @$core.pragma('dart2js:noInline')
  static AudioChunk getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AudioChunk>(create);
  static AudioChunk? _defaultInstance;

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
  AudioFormat get format => $_getN(2);
  @$pb.TagNumber(3)
  set format(AudioFormat v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasFormat() => $_has(2);
  @$pb.TagNumber(3)
  void clearFormat() => clearField(3);
  @$pb.TagNumber(3)
  AudioFormat ensureFormat() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.List<$core.int> get audio => $_getN(3);
  @$pb.TagNumber(4)
  set audio($core.List<$core.int> v) { $_setBytes(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAudio() => $_has(3);
  @$pb.TagNumber(4)
  void clearAudio() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get endOfStream => $_getBF(4);
  @$pb.TagNumber(5)
  set endOfStream($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasEndOfStream() => $_has(4);
  @$pb.TagNumber(5)
  void clearEndOfStream() => clearField(5);
}

///  -----------------------------------------------------------------------------
///  StageTrace
///
///  One entry per IntentPipeline stage (FastPath / Embedding / LLM / ...).
///
///    stage_name      : pipeline position label from config — e.g.
///                      "fastpath", "embedding", "llm". Stable across runs.
///    classifier_name : implementation that produced the result for this
///                      stage (e.g. "RegexFastPathRouter", "EmbeddingClassifier",
///                      "LlmRouter"). May vary per pipeline_id.
///
///  Both are included because the same classifier can occupy different stages
///  across pipelines, and the same stage label may host different classifiers.
///  -----------------------------------------------------------------------------
class StageTrace extends $pb.GeneratedMessage {
  factory StageTrace({
    $core.String? stageName,
    $core.String? classifierName,
    IntentKind? intent,
    $core.String? toolName,
    $core.double? confidence,
    $core.String? rawJson,
  }) {
    final $result = create();
    if (stageName != null) {
      $result.stageName = stageName;
    }
    if (classifierName != null) {
      $result.classifierName = classifierName;
    }
    if (intent != null) {
      $result.intent = intent;
    }
    if (toolName != null) {
      $result.toolName = toolName;
    }
    if (confidence != null) {
      $result.confidence = confidence;
    }
    if (rawJson != null) {
      $result.rawJson = rawJson;
    }
    return $result;
  }
  StageTrace._() : super();
  factory StageTrace.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory StageTrace.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'StageTrace', package: const $pb.PackageName(_omitMessageNames ? '' : 'oais.common.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'stageName')
    ..aOS(2, _omitFieldNames ? '' : 'classifierName')
    ..e<IntentKind>(3, _omitFieldNames ? '' : 'intent', $pb.PbFieldType.OE, defaultOrMaker: IntentKind.INTENT_UNKNOWN, valueOf: IntentKind.valueOf, enumValues: IntentKind.values)
    ..aOS(4, _omitFieldNames ? '' : 'toolName')
    ..a<$core.double>(5, _omitFieldNames ? '' : 'confidence', $pb.PbFieldType.OD)
    ..aOS(6, _omitFieldNames ? '' : 'rawJson')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  StageTrace clone() => StageTrace()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  StageTrace copyWith(void Function(StageTrace) updates) => super.copyWith((message) => updates(message as StageTrace)) as StageTrace;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StageTrace create() => StageTrace._();
  StageTrace createEmptyInstance() => create();
  static $pb.PbList<StageTrace> createRepeated() => $pb.PbList<StageTrace>();
  @$core.pragma('dart2js:noInline')
  static StageTrace getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StageTrace>(create);
  static StageTrace? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get stageName => $_getSZ(0);
  @$pb.TagNumber(1)
  set stageName($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasStageName() => $_has(0);
  @$pb.TagNumber(1)
  void clearStageName() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get classifierName => $_getSZ(1);
  @$pb.TagNumber(2)
  set classifierName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasClassifierName() => $_has(1);
  @$pb.TagNumber(2)
  void clearClassifierName() => clearField(2);

  @$pb.TagNumber(3)
  IntentKind get intent => $_getN(2);
  @$pb.TagNumber(3)
  set intent(IntentKind v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasIntent() => $_has(2);
  @$pb.TagNumber(3)
  void clearIntent() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get toolName => $_getSZ(3);
  @$pb.TagNumber(4)
  set toolName($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasToolName() => $_has(3);
  @$pb.TagNumber(4)
  void clearToolName() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get confidence => $_getN(4);
  @$pb.TagNumber(5)
  set confidence($core.double v) { $_setDouble(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasConfidence() => $_has(4);
  @$pb.TagNumber(5)
  void clearConfidence() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get rawJson => $_getSZ(5);
  @$pb.TagNumber(6)
  set rawJson($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasRawJson() => $_has(5);
  @$pb.TagNumber(6)
  void clearRawJson() => clearField(6);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
