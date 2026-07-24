//
//  Generated code. Do not modify.
//  source: agl_shell.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ActivateRequest extends $pb.GeneratedMessage {
  factory ActivateRequest({
    $core.String? appId,
    $core.String? outputName,
  }) {
    final $result = create();
    if (appId != null) {
      $result.appId = appId;
    }
    if (outputName != null) {
      $result.outputName = outputName;
    }
    return $result;
  }
  ActivateRequest._() : super();
  factory ActivateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ActivateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ActivateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'agl_shell_ipc'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'appId')
    ..aOS(2, _omitFieldNames ? '' : 'outputName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ActivateRequest clone() => ActivateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ActivateRequest copyWith(void Function(ActivateRequest) updates) => super.copyWith((message) => updates(message as ActivateRequest)) as ActivateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivateRequest create() => ActivateRequest._();
  ActivateRequest createEmptyInstance() => create();
  static $pb.PbList<ActivateRequest> createRepeated() => $pb.PbList<ActivateRequest>();
  @$core.pragma('dart2js:noInline')
  static ActivateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ActivateRequest>(create);
  static ActivateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get appId => $_getSZ(0);
  @$pb.TagNumber(1)
  set appId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAppId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get outputName => $_getSZ(1);
  @$pb.TagNumber(2)
  set outputName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOutputName() => $_has(1);
  @$pb.TagNumber(2)
  void clearOutputName() => clearField(2);
}

class ActivateResponse extends $pb.GeneratedMessage {
  factory ActivateResponse() => create();
  ActivateResponse._() : super();
  factory ActivateResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ActivateResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ActivateResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'agl_shell_ipc'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ActivateResponse clone() => ActivateResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ActivateResponse copyWith(void Function(ActivateResponse) updates) => super.copyWith((message) => updates(message as ActivateResponse)) as ActivateResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActivateResponse create() => ActivateResponse._();
  ActivateResponse createEmptyInstance() => create();
  static $pb.PbList<ActivateResponse> createRepeated() => $pb.PbList<ActivateResponse>();
  @$core.pragma('dart2js:noInline')
  static ActivateResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ActivateResponse>(create);
  static ActivateResponse? _defaultInstance;
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
