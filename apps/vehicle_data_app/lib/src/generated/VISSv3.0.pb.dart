//
//  Generated code. Do not modify.
//  source: VISSv3.0.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'VISSv3.0.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'VISSv3.0.pbenum.dart';

class ErrorResponseMessage extends $pb.GeneratedMessage {
  factory ErrorResponseMessage({
    $core.String? number,
    $core.String? reason,
    $core.String? description,
  }) {
    final $result = create();
    if (number != null) {
      $result.number = number;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    if (description != null) {
      $result.description = description;
    }
    return $result;
  }
  ErrorResponseMessage._() : super();
  factory ErrorResponseMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ErrorResponseMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ErrorResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Number', protoName: 'Number')
    ..aOS(2, _omitFieldNames ? '' : 'Reason', protoName: 'Reason')
    ..aOS(3, _omitFieldNames ? '' : 'Description', protoName: 'Description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorResponseMessage clone() =>
      ErrorResponseMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ErrorResponseMessage copyWith(void Function(ErrorResponseMessage) updates) =>
      super.copyWith((message) => updates(message as ErrorResponseMessage))
          as ErrorResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ErrorResponseMessage create() => ErrorResponseMessage._();
  ErrorResponseMessage createEmptyInstance() => create();
  static $pb.PbList<ErrorResponseMessage> createRepeated() =>
      $pb.PbList<ErrorResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static ErrorResponseMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ErrorResponseMessage>(create);
  static ErrorResponseMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get number => $_getSZ(0);
  @$pb.TagNumber(1)
  set number($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearNumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);
}

class FilterExpressions_FilterExpression_FilterValue_PathsValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_PathsValue({
    $core.Iterable<$core.String>? relativePath,
  }) {
    final $result = create();
    if (relativePath != null) {
      $result.relativePath.addAll(relativePath);
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_PathsValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_PathsValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_PathsValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.PathsValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'RelativePath', protoName: 'RelativePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_PathsValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_PathsValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_PathsValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_PathsValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_PathsValue))
          as FilterExpressions_FilterExpression_FilterValue_PathsValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_PathsValue create() =>
      FilterExpressions_FilterExpression_FilterValue_PathsValue._();
  FilterExpressions_FilterExpression_FilterValue_PathsValue
      createEmptyInstance() => create();
  static $pb.PbList<FilterExpressions_FilterExpression_FilterValue_PathsValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_PathsValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_PathsValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue_PathsValue>(create);
  static FilterExpressions_FilterExpression_FilterValue_PathsValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get relativePath => $_getList(0);
}

class FilterExpressions_FilterExpression_FilterValue_TimebasedValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_TimebasedValue({
    $core.String? period,
  }) {
    final $result = create();
    if (period != null) {
      $result.period = period;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_TimebasedValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_TimebasedValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_TimebasedValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.TimebasedValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Period', protoName: 'Period')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_TimebasedValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_TimebasedValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_TimebasedValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_TimebasedValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_TimebasedValue))
          as FilterExpressions_FilterExpression_FilterValue_TimebasedValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_TimebasedValue
      create() =>
          FilterExpressions_FilterExpression_FilterValue_TimebasedValue._();
  FilterExpressions_FilterExpression_FilterValue_TimebasedValue
      createEmptyInstance() => create();
  static $pb
      .PbList<FilterExpressions_FilterExpression_FilterValue_TimebasedValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_TimebasedValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_TimebasedValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              FilterExpressions_FilterExpression_FilterValue_TimebasedValue>(
          create);
  static FilterExpressions_FilterExpression_FilterValue_TimebasedValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get period => $_getSZ(0);
  @$pb.TagNumber(1)
  set period($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPeriod() => $_has(0);
  @$pb.TagNumber(1)
  void clearPeriod() => $_clearField(1);
}

class FilterExpressions_FilterExpression_FilterValue_RangeValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_RangeValue({
    $core.String? logicOperator,
    $core.String? boundary,
  }) {
    final $result = create();
    if (logicOperator != null) {
      $result.logicOperator = logicOperator;
    }
    if (boundary != null) {
      $result.boundary = boundary;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_RangeValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_RangeValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_RangeValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.RangeValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'LogicOperator', protoName: 'LogicOperator')
    ..aOS(2, _omitFieldNames ? '' : 'Boundary', protoName: 'Boundary')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_RangeValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_RangeValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_RangeValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_RangeValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_RangeValue))
          as FilterExpressions_FilterExpression_FilterValue_RangeValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_RangeValue create() =>
      FilterExpressions_FilterExpression_FilterValue_RangeValue._();
  FilterExpressions_FilterExpression_FilterValue_RangeValue
      createEmptyInstance() => create();
  static $pb.PbList<FilterExpressions_FilterExpression_FilterValue_RangeValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_RangeValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_RangeValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue_RangeValue>(create);
  static FilterExpressions_FilterExpression_FilterValue_RangeValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get logicOperator => $_getSZ(0);
  @$pb.TagNumber(1)
  set logicOperator($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasLogicOperator() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogicOperator() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get boundary => $_getSZ(1);
  @$pb.TagNumber(2)
  set boundary($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasBoundary() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoundary() => $_clearField(2);
}

class FilterExpressions_FilterExpression_FilterValue_ChangeValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_ChangeValue({
    $core.String? logicOperator,
    $core.String? diff,
  }) {
    final $result = create();
    if (logicOperator != null) {
      $result.logicOperator = logicOperator;
    }
    if (diff != null) {
      $result.diff = diff;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_ChangeValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_ChangeValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_ChangeValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.ChangeValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'LogicOperator', protoName: 'LogicOperator')
    ..aOS(2, _omitFieldNames ? '' : 'Diff', protoName: 'Diff')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_ChangeValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_ChangeValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_ChangeValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_ChangeValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_ChangeValue))
          as FilterExpressions_FilterExpression_FilterValue_ChangeValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_ChangeValue create() =>
      FilterExpressions_FilterExpression_FilterValue_ChangeValue._();
  FilterExpressions_FilterExpression_FilterValue_ChangeValue
      createEmptyInstance() => create();
  static $pb.PbList<FilterExpressions_FilterExpression_FilterValue_ChangeValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_ChangeValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_ChangeValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue_ChangeValue>(create);
  static FilterExpressions_FilterExpression_FilterValue_ChangeValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get logicOperator => $_getSZ(0);
  @$pb.TagNumber(1)
  set logicOperator($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasLogicOperator() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogicOperator() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get diff => $_getSZ(1);
  @$pb.TagNumber(2)
  set diff($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDiff() => $_has(1);
  @$pb.TagNumber(2)
  void clearDiff() => $_clearField(2);
}

class FilterExpressions_FilterExpression_FilterValue_CurvelogValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_CurvelogValue({
    $core.String? maxErr,
    $core.String? bufSize,
  }) {
    final $result = create();
    if (maxErr != null) {
      $result.maxErr = maxErr;
    }
    if (bufSize != null) {
      $result.bufSize = bufSize;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_CurvelogValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_CurvelogValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_CurvelogValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.CurvelogValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'MaxErr', protoName: 'MaxErr')
    ..aOS(2, _omitFieldNames ? '' : 'BufSize', protoName: 'BufSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_CurvelogValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_CurvelogValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_CurvelogValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_CurvelogValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_CurvelogValue))
          as FilterExpressions_FilterExpression_FilterValue_CurvelogValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_CurvelogValue
      create() =>
          FilterExpressions_FilterExpression_FilterValue_CurvelogValue._();
  FilterExpressions_FilterExpression_FilterValue_CurvelogValue
      createEmptyInstance() => create();
  static $pb
      .PbList<FilterExpressions_FilterExpression_FilterValue_CurvelogValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_CurvelogValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_CurvelogValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue_CurvelogValue>(create);
  static FilterExpressions_FilterExpression_FilterValue_CurvelogValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get maxErr => $_getSZ(0);
  @$pb.TagNumber(1)
  set maxErr($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMaxErr() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaxErr() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bufSize => $_getSZ(1);
  @$pb.TagNumber(2)
  set bufSize($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasBufSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearBufSize() => $_clearField(2);
}

class FilterExpressions_FilterExpression_FilterValue_HistoryValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_HistoryValue({
    $core.String? timePeriod,
  }) {
    final $result = create();
    if (timePeriod != null) {
      $result.timePeriod = timePeriod;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_HistoryValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_HistoryValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_HistoryValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.HistoryValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'TimePeriod', protoName: 'TimePeriod')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_HistoryValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_HistoryValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_HistoryValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_HistoryValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_HistoryValue))
          as FilterExpressions_FilterExpression_FilterValue_HistoryValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_HistoryValue create() =>
      FilterExpressions_FilterExpression_FilterValue_HistoryValue._();
  FilterExpressions_FilterExpression_FilterValue_HistoryValue
      createEmptyInstance() => create();
  static $pb.PbList<FilterExpressions_FilterExpression_FilterValue_HistoryValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_HistoryValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_HistoryValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue_HistoryValue>(create);
  static FilterExpressions_FilterExpression_FilterValue_HistoryValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get timePeriod => $_getSZ(0);
  @$pb.TagNumber(1)
  set timePeriod($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTimePeriod() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimePeriod() => $_clearField(1);
}

class FilterExpressions_FilterExpression_FilterValue_MetadataValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue_MetadataValue({
    $core.String? tree,
  }) {
    final $result = create();
    if (tree != null) {
      $result.tree = tree;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue_MetadataValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue_MetadataValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue_MetadataValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'FilterExpressions.FilterExpression.FilterValue.MetadataValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Tree', protoName: 'Tree')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_MetadataValue clone() =>
      FilterExpressions_FilterExpression_FilterValue_MetadataValue()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue_MetadataValue copyWith(
          void Function(
                  FilterExpressions_FilterExpression_FilterValue_MetadataValue)
              updates) =>
      super.copyWith((message) => updates(message
              as FilterExpressions_FilterExpression_FilterValue_MetadataValue))
          as FilterExpressions_FilterExpression_FilterValue_MetadataValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_MetadataValue
      create() =>
          FilterExpressions_FilterExpression_FilterValue_MetadataValue._();
  FilterExpressions_FilterExpression_FilterValue_MetadataValue
      createEmptyInstance() => create();
  static $pb
      .PbList<FilterExpressions_FilterExpression_FilterValue_MetadataValue>
      createRepeated() => $pb.PbList<
          FilterExpressions_FilterExpression_FilterValue_MetadataValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue_MetadataValue
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue_MetadataValue>(create);
  static FilterExpressions_FilterExpression_FilterValue_MetadataValue?
      _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tree => $_getSZ(0);
  @$pb.TagNumber(1)
  set tree($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasTree() => $_has(0);
  @$pb.TagNumber(1)
  void clearTree() => $_clearField(1);
}

class FilterExpressions_FilterExpression_FilterValue
    extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression_FilterValue({
    FilterExpressions_FilterExpression_FilterValue_PathsValue? valuePaths,
    FilterExpressions_FilterExpression_FilterValue_TimebasedValue?
        valueTimebased,
    $core.Iterable<FilterExpressions_FilterExpression_FilterValue_RangeValue>?
        valueRange,
    FilterExpressions_FilterExpression_FilterValue_ChangeValue? valueChange,
    FilterExpressions_FilterExpression_FilterValue_CurvelogValue? valueCurvelog,
    FilterExpressions_FilterExpression_FilterValue_HistoryValue? valueHistory,
    FilterExpressions_FilterExpression_FilterValue_MetadataValue? valueMetadata,
  }) {
    final $result = create();
    if (valuePaths != null) {
      $result.valuePaths = valuePaths;
    }
    if (valueTimebased != null) {
      $result.valueTimebased = valueTimebased;
    }
    if (valueRange != null) {
      $result.valueRange.addAll(valueRange);
    }
    if (valueChange != null) {
      $result.valueChange = valueChange;
    }
    if (valueCurvelog != null) {
      $result.valueCurvelog = valueCurvelog;
    }
    if (valueHistory != null) {
      $result.valueHistory = valueHistory;
    }
    if (valueMetadata != null) {
      $result.valueMetadata = valueMetadata;
    }
    return $result;
  }
  FilterExpressions_FilterExpression_FilterValue._() : super();
  factory FilterExpressions_FilterExpression_FilterValue.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression_FilterValue.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FilterExpressions.FilterExpression.FilterValue',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOM<FilterExpressions_FilterExpression_FilterValue_PathsValue>(
        1, _omitFieldNames ? '' : 'ValuePaths',
        protoName: 'ValuePaths',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_PathsValue.create)
    ..aOM<FilterExpressions_FilterExpression_FilterValue_TimebasedValue>(
        2, _omitFieldNames ? '' : 'ValueTimebased',
        protoName: 'ValueTimebased',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_TimebasedValue
                .create)
    ..pc<FilterExpressions_FilterExpression_FilterValue_RangeValue>(
        3, _omitFieldNames ? '' : 'ValueRange', $pb.PbFieldType.PM,
        protoName: 'ValueRange',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_RangeValue.create)
    ..aOM<FilterExpressions_FilterExpression_FilterValue_ChangeValue>(
        4, _omitFieldNames ? '' : 'ValueChange',
        protoName: 'ValueChange',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_ChangeValue.create)
    ..aOM<FilterExpressions_FilterExpression_FilterValue_CurvelogValue>(
        5, _omitFieldNames ? '' : 'ValueCurvelog',
        protoName: 'ValueCurvelog',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_CurvelogValue.create)
    ..aOM<FilterExpressions_FilterExpression_FilterValue_HistoryValue>(
        6, _omitFieldNames ? '' : 'ValueHistory',
        protoName: 'ValueHistory',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_HistoryValue.create)
    ..aOM<FilterExpressions_FilterExpression_FilterValue_MetadataValue>(
        7, _omitFieldNames ? '' : 'ValueMetadata',
        protoName: 'ValueMetadata',
        subBuilder:
            FilterExpressions_FilterExpression_FilterValue_MetadataValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue clone() =>
      FilterExpressions_FilterExpression_FilterValue()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression_FilterValue copyWith(
          void Function(FilterExpressions_FilterExpression_FilterValue)
              updates) =>
      super.copyWith((message) => updates(
              message as FilterExpressions_FilterExpression_FilterValue))
          as FilterExpressions_FilterExpression_FilterValue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue create() =>
      FilterExpressions_FilterExpression_FilterValue._();
  FilterExpressions_FilterExpression_FilterValue createEmptyInstance() =>
      create();
  static $pb.PbList<FilterExpressions_FilterExpression_FilterValue>
      createRepeated() =>
          $pb.PbList<FilterExpressions_FilterExpression_FilterValue>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression_FilterValue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          FilterExpressions_FilterExpression_FilterValue>(create);
  static FilterExpressions_FilterExpression_FilterValue? _defaultInstance;

  @$pb.TagNumber(1)
  FilterExpressions_FilterExpression_FilterValue_PathsValue get valuePaths =>
      $_getN(0);
  @$pb.TagNumber(1)
  set valuePaths(FilterExpressions_FilterExpression_FilterValue_PathsValue v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasValuePaths() => $_has(0);
  @$pb.TagNumber(1)
  void clearValuePaths() => $_clearField(1);
  @$pb.TagNumber(1)
  FilterExpressions_FilterExpression_FilterValue_PathsValue
      ensureValuePaths() => $_ensure(0);

  @$pb.TagNumber(2)
  FilterExpressions_FilterExpression_FilterValue_TimebasedValue
      get valueTimebased => $_getN(1);
  @$pb.TagNumber(2)
  set valueTimebased(
      FilterExpressions_FilterExpression_FilterValue_TimebasedValue v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValueTimebased() => $_has(1);
  @$pb.TagNumber(2)
  void clearValueTimebased() => $_clearField(2);
  @$pb.TagNumber(2)
  FilterExpressions_FilterExpression_FilterValue_TimebasedValue
      ensureValueTimebased() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<FilterExpressions_FilterExpression_FilterValue_RangeValue>
      get valueRange => $_getList(2);

  @$pb.TagNumber(4)
  FilterExpressions_FilterExpression_FilterValue_ChangeValue get valueChange =>
      $_getN(3);
  @$pb.TagNumber(4)
  set valueChange(
      FilterExpressions_FilterExpression_FilterValue_ChangeValue v) {
    $_setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasValueChange() => $_has(3);
  @$pb.TagNumber(4)
  void clearValueChange() => $_clearField(4);
  @$pb.TagNumber(4)
  FilterExpressions_FilterExpression_FilterValue_ChangeValue
      ensureValueChange() => $_ensure(3);

  @$pb.TagNumber(5)
  FilterExpressions_FilterExpression_FilterValue_CurvelogValue
      get valueCurvelog => $_getN(4);
  @$pb.TagNumber(5)
  set valueCurvelog(
      FilterExpressions_FilterExpression_FilterValue_CurvelogValue v) {
    $_setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasValueCurvelog() => $_has(4);
  @$pb.TagNumber(5)
  void clearValueCurvelog() => $_clearField(5);
  @$pb.TagNumber(5)
  FilterExpressions_FilterExpression_FilterValue_CurvelogValue
      ensureValueCurvelog() => $_ensure(4);

  @$pb.TagNumber(6)
  FilterExpressions_FilterExpression_FilterValue_HistoryValue
      get valueHistory => $_getN(5);
  @$pb.TagNumber(6)
  set valueHistory(
      FilterExpressions_FilterExpression_FilterValue_HistoryValue v) {
    $_setField(6, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasValueHistory() => $_has(5);
  @$pb.TagNumber(6)
  void clearValueHistory() => $_clearField(6);
  @$pb.TagNumber(6)
  FilterExpressions_FilterExpression_FilterValue_HistoryValue
      ensureValueHistory() => $_ensure(5);

  @$pb.TagNumber(7)
  FilterExpressions_FilterExpression_FilterValue_MetadataValue
      get valueMetadata => $_getN(6);
  @$pb.TagNumber(7)
  set valueMetadata(
      FilterExpressions_FilterExpression_FilterValue_MetadataValue v) {
    $_setField(7, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasValueMetadata() => $_has(6);
  @$pb.TagNumber(7)
  void clearValueMetadata() => $_clearField(7);
  @$pb.TagNumber(7)
  FilterExpressions_FilterExpression_FilterValue_MetadataValue
      ensureValueMetadata() => $_ensure(6);
}

class FilterExpressions_FilterExpression extends $pb.GeneratedMessage {
  factory FilterExpressions_FilterExpression({
    FilterExpressions_FilterExpression_FilterVariant? variant,
    FilterExpressions_FilterExpression_FilterValue? value,
  }) {
    final $result = create();
    if (variant != null) {
      $result.variant = variant;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  FilterExpressions_FilterExpression._() : super();
  factory FilterExpressions_FilterExpression.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions_FilterExpression.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FilterExpressions.FilterExpression',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..e<FilterExpressions_FilterExpression_FilterVariant>(
        1, _omitFieldNames ? '' : 'Variant', $pb.PbFieldType.OE,
        protoName: 'Variant',
        defaultOrMaker: FilterExpressions_FilterExpression_FilterVariant.PATHS,
        valueOf: FilterExpressions_FilterExpression_FilterVariant.valueOf,
        enumValues: FilterExpressions_FilterExpression_FilterVariant.values)
    ..aOM<FilterExpressions_FilterExpression_FilterValue>(
        2, _omitFieldNames ? '' : 'Value',
        protoName: 'Value',
        subBuilder: FilterExpressions_FilterExpression_FilterValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression clone() =>
      FilterExpressions_FilterExpression()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions_FilterExpression copyWith(
          void Function(FilterExpressions_FilterExpression) updates) =>
      super.copyWith((message) =>
              updates(message as FilterExpressions_FilterExpression))
          as FilterExpressions_FilterExpression;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression create() =>
      FilterExpressions_FilterExpression._();
  FilterExpressions_FilterExpression createEmptyInstance() => create();
  static $pb.PbList<FilterExpressions_FilterExpression> createRepeated() =>
      $pb.PbList<FilterExpressions_FilterExpression>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions_FilterExpression getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FilterExpressions_FilterExpression>(
          create);
  static FilterExpressions_FilterExpression? _defaultInstance;

  @$pb.TagNumber(1)
  FilterExpressions_FilterExpression_FilterVariant get variant => $_getN(0);
  @$pb.TagNumber(1)
  set variant(FilterExpressions_FilterExpression_FilterVariant v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasVariant() => $_has(0);
  @$pb.TagNumber(1)
  void clearVariant() => $_clearField(1);

  @$pb.TagNumber(2)
  FilterExpressions_FilterExpression_FilterValue get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(FilterExpressions_FilterExpression_FilterValue v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);
  @$pb.TagNumber(2)
  FilterExpressions_FilterExpression_FilterValue ensureValue() => $_ensure(1);
}

class FilterExpressions extends $pb.GeneratedMessage {
  factory FilterExpressions({
    $core.Iterable<FilterExpressions_FilterExpression>? filterExp,
  }) {
    final $result = create();
    if (filterExp != null) {
      $result.filterExp.addAll(filterExp);
    }
    return $result;
  }
  FilterExpressions._() : super();
  factory FilterExpressions.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FilterExpressions.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FilterExpressions',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..pc<FilterExpressions_FilterExpression>(
        1, _omitFieldNames ? '' : 'FilterExp', $pb.PbFieldType.PM,
        protoName: 'FilterExp',
        subBuilder: FilterExpressions_FilterExpression.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions clone() => FilterExpressions()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FilterExpressions copyWith(void Function(FilterExpressions) updates) =>
      super.copyWith((message) => updates(message as FilterExpressions))
          as FilterExpressions;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterExpressions create() => FilterExpressions._();
  FilterExpressions createEmptyInstance() => create();
  static $pb.PbList<FilterExpressions> createRepeated() =>
      $pb.PbList<FilterExpressions>();
  @$core.pragma('dart2js:noInline')
  static FilterExpressions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FilterExpressions>(create);
  static FilterExpressions? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FilterExpressions_FilterExpression> get filterExp => $_getList(0);
}

class DataPackages_DataPackage_DataPoint extends $pb.GeneratedMessage {
  factory DataPackages_DataPackage_DataPoint({
    $core.String? value,
    $core.String? ts,
  }) {
    final $result = create();
    if (value != null) {
      $result.value = value;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    return $result;
  }
  DataPackages_DataPackage_DataPoint._() : super();
  factory DataPackages_DataPackage_DataPoint.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DataPackages_DataPackage_DataPoint.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DataPackages.DataPackage.DataPoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Value', protoName: 'Value')
    ..aOS(2, _omitFieldNames ? '' : 'Ts', protoName: 'Ts')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataPackages_DataPackage_DataPoint clone() =>
      DataPackages_DataPackage_DataPoint()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataPackages_DataPackage_DataPoint copyWith(
          void Function(DataPackages_DataPackage_DataPoint) updates) =>
      super.copyWith((message) =>
              updates(message as DataPackages_DataPackage_DataPoint))
          as DataPackages_DataPackage_DataPoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DataPackages_DataPackage_DataPoint create() =>
      DataPackages_DataPackage_DataPoint._();
  DataPackages_DataPackage_DataPoint createEmptyInstance() => create();
  static $pb.PbList<DataPackages_DataPackage_DataPoint> createRepeated() =>
      $pb.PbList<DataPackages_DataPackage_DataPoint>();
  @$core.pragma('dart2js:noInline')
  static DataPackages_DataPackage_DataPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DataPackages_DataPackage_DataPoint>(
          create);
  static DataPackages_DataPackage_DataPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get ts => $_getSZ(1);
  @$pb.TagNumber(2)
  set ts($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTs() => $_has(1);
  @$pb.TagNumber(2)
  void clearTs() => $_clearField(2);
}

class DataPackages_DataPackage extends $pb.GeneratedMessage {
  factory DataPackages_DataPackage({
    $core.String? path,
    $core.Iterable<DataPackages_DataPackage_DataPoint>? dp,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    if (dp != null) {
      $result.dp.addAll(dp);
    }
    return $result;
  }
  DataPackages_DataPackage._() : super();
  factory DataPackages_DataPackage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DataPackages_DataPackage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DataPackages.DataPackage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Path', protoName: 'Path')
    ..pc<DataPackages_DataPackage_DataPoint>(
        2, _omitFieldNames ? '' : 'Dp', $pb.PbFieldType.PM,
        protoName: 'Dp', subBuilder: DataPackages_DataPackage_DataPoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataPackages_DataPackage clone() =>
      DataPackages_DataPackage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataPackages_DataPackage copyWith(
          void Function(DataPackages_DataPackage) updates) =>
      super.copyWith((message) => updates(message as DataPackages_DataPackage))
          as DataPackages_DataPackage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DataPackages_DataPackage create() => DataPackages_DataPackage._();
  DataPackages_DataPackage createEmptyInstance() => create();
  static $pb.PbList<DataPackages_DataPackage> createRepeated() =>
      $pb.PbList<DataPackages_DataPackage>();
  @$core.pragma('dart2js:noInline')
  static DataPackages_DataPackage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DataPackages_DataPackage>(create);
  static DataPackages_DataPackage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<DataPackages_DataPackage_DataPoint> get dp => $_getList(1);
}

class DataPackages extends $pb.GeneratedMessage {
  factory DataPackages({
    $core.Iterable<DataPackages_DataPackage>? data,
  }) {
    final $result = create();
    if (data != null) {
      $result.data.addAll(data);
    }
    return $result;
  }
  DataPackages._() : super();
  factory DataPackages.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DataPackages.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DataPackages',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..pc<DataPackages_DataPackage>(
        1, _omitFieldNames ? '' : 'Data', $pb.PbFieldType.PM,
        protoName: 'Data', subBuilder: DataPackages_DataPackage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataPackages clone() => DataPackages()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DataPackages copyWith(void Function(DataPackages) updates) =>
      super.copyWith((message) => updates(message as DataPackages))
          as DataPackages;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DataPackages create() => DataPackages._();
  DataPackages createEmptyInstance() => create();
  static $pb.PbList<DataPackages> createRepeated() =>
      $pb.PbList<DataPackages>();
  @$core.pragma('dart2js:noInline')
  static DataPackages getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DataPackages>(create);
  static DataPackages? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DataPackages_DataPackage> get data => $_getList(0);
}

class GetRequestMessage extends $pb.GeneratedMessage {
  factory GetRequestMessage({
    $core.String? path,
    FilterExpressions? filter,
    $core.String? authorization,
    $core.String? dataCompression,
    $core.String? requestId,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    if (filter != null) {
      $result.filter = filter;
    }
    if (authorization != null) {
      $result.authorization = authorization;
    }
    if (dataCompression != null) {
      $result.dataCompression = dataCompression;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    return $result;
  }
  GetRequestMessage._() : super();
  factory GetRequestMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GetRequestMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRequestMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Path', protoName: 'Path')
    ..aOM<FilterExpressions>(2, _omitFieldNames ? '' : 'Filter',
        protoName: 'Filter', subBuilder: FilterExpressions.create)
    ..aOS(3, _omitFieldNames ? '' : 'Authorization', protoName: 'Authorization')
    ..aOS(4, _omitFieldNames ? '' : 'DataCompression',
        protoName: 'DataCompression')
    ..aOS(5, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequestMessage clone() => GetRequestMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequestMessage copyWith(void Function(GetRequestMessage) updates) =>
      super.copyWith((message) => updates(message as GetRequestMessage))
          as GetRequestMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRequestMessage create() => GetRequestMessage._();
  GetRequestMessage createEmptyInstance() => create();
  static $pb.PbList<GetRequestMessage> createRepeated() =>
      $pb.PbList<GetRequestMessage>();
  @$core.pragma('dart2js:noInline')
  static GetRequestMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRequestMessage>(create);
  static GetRequestMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  FilterExpressions get filter => $_getN(1);
  @$pb.TagNumber(2)
  set filter(FilterExpressions v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasFilter() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilter() => $_clearField(2);
  @$pb.TagNumber(2)
  FilterExpressions ensureFilter() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get authorization => $_getSZ(2);
  @$pb.TagNumber(3)
  set authorization($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasAuthorization() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthorization() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get dataCompression => $_getSZ(3);
  @$pb.TagNumber(4)
  set dataCompression($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasDataCompression() => $_has(3);
  @$pb.TagNumber(4)
  void clearDataCompression() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get requestId => $_getSZ(4);
  @$pb.TagNumber(5)
  set requestId($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasRequestId() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestId() => $_clearField(5);
}

class GetResponseMessage_SuccessResponseMessage extends $pb.GeneratedMessage {
  factory GetResponseMessage_SuccessResponseMessage({
    DataPackages? dataPack,
    $core.String? metadata,
  }) {
    final $result = create();
    if (dataPack != null) {
      $result.dataPack = dataPack;
    }
    if (metadata != null) {
      $result.metadata = metadata;
    }
    return $result;
  }
  GetResponseMessage_SuccessResponseMessage._() : super();
  factory GetResponseMessage_SuccessResponseMessage.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GetResponseMessage_SuccessResponseMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetResponseMessage.SuccessResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOM<DataPackages>(1, _omitFieldNames ? '' : 'DataPack',
        protoName: 'DataPack', subBuilder: DataPackages.create)
    ..aOS(2, _omitFieldNames ? '' : 'Metadata', protoName: 'Metadata')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetResponseMessage_SuccessResponseMessage clone() =>
      GetResponseMessage_SuccessResponseMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetResponseMessage_SuccessResponseMessage copyWith(
          void Function(GetResponseMessage_SuccessResponseMessage) updates) =>
      super.copyWith((message) =>
              updates(message as GetResponseMessage_SuccessResponseMessage))
          as GetResponseMessage_SuccessResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetResponseMessage_SuccessResponseMessage create() =>
      GetResponseMessage_SuccessResponseMessage._();
  GetResponseMessage_SuccessResponseMessage createEmptyInstance() => create();
  static $pb.PbList<GetResponseMessage_SuccessResponseMessage>
      createRepeated() =>
          $pb.PbList<GetResponseMessage_SuccessResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static GetResponseMessage_SuccessResponseMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetResponseMessage_SuccessResponseMessage>(create);
  static GetResponseMessage_SuccessResponseMessage? _defaultInstance;

  @$pb.TagNumber(1)
  DataPackages get dataPack => $_getN(0);
  @$pb.TagNumber(1)
  set dataPack(DataPackages v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasDataPack() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataPack() => $_clearField(1);
  @$pb.TagNumber(1)
  DataPackages ensureDataPack() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get metadata => $_getSZ(1);
  @$pb.TagNumber(2)
  set metadata($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMetadata() => $_has(1);
  @$pb.TagNumber(2)
  void clearMetadata() => $_clearField(2);
}

class GetResponseMessage extends $pb.GeneratedMessage {
  factory GetResponseMessage({
    ResponseStatus? status,
    GetResponseMessage_SuccessResponseMessage? successResponse,
    ErrorResponseMessage? errorResponse,
    $core.String? requestId,
    $core.String? ts,
    $core.String? authorization,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (successResponse != null) {
      $result.successResponse = successResponse;
    }
    if (errorResponse != null) {
      $result.errorResponse = errorResponse;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    if (authorization != null) {
      $result.authorization = authorization;
    }
    return $result;
  }
  GetResponseMessage._() : super();
  factory GetResponseMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory GetResponseMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..e<ResponseStatus>(1, _omitFieldNames ? '' : 'Status', $pb.PbFieldType.OE,
        protoName: 'Status',
        defaultOrMaker: ResponseStatus.SUCCESS,
        valueOf: ResponseStatus.valueOf,
        enumValues: ResponseStatus.values)
    ..aOM<GetResponseMessage_SuccessResponseMessage>(
        2, _omitFieldNames ? '' : 'SuccessResponse',
        protoName: 'SuccessResponse',
        subBuilder: GetResponseMessage_SuccessResponseMessage.create)
    ..aOM<ErrorResponseMessage>(3, _omitFieldNames ? '' : 'ErrorResponse',
        protoName: 'ErrorResponse', subBuilder: ErrorResponseMessage.create)
    ..aOS(4, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..aOS(5, _omitFieldNames ? '' : 'Ts', protoName: 'Ts')
    ..aOS(6, _omitFieldNames ? '' : 'Authorization', protoName: 'Authorization')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetResponseMessage clone() => GetResponseMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetResponseMessage copyWith(void Function(GetResponseMessage) updates) =>
      super.copyWith((message) => updates(message as GetResponseMessage))
          as GetResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetResponseMessage create() => GetResponseMessage._();
  GetResponseMessage createEmptyInstance() => create();
  static $pb.PbList<GetResponseMessage> createRepeated() =>
      $pb.PbList<GetResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static GetResponseMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetResponseMessage>(create);
  static GetResponseMessage? _defaultInstance;

  @$pb.TagNumber(1)
  ResponseStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(ResponseStatus v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  GetResponseMessage_SuccessResponseMessage get successResponse => $_getN(1);
  @$pb.TagNumber(2)
  set successResponse(GetResponseMessage_SuccessResponseMessage v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasSuccessResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccessResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  GetResponseMessage_SuccessResponseMessage ensureSuccessResponse() =>
      $_ensure(1);

  @$pb.TagNumber(3)
  ErrorResponseMessage get errorResponse => $_getN(2);
  @$pb.TagNumber(3)
  set errorResponse(ErrorResponseMessage v) {
    $_setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasErrorResponse() => $_has(2);
  @$pb.TagNumber(3)
  void clearErrorResponse() => $_clearField(3);
  @$pb.TagNumber(3)
  ErrorResponseMessage ensureErrorResponse() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get requestId => $_getSZ(3);
  @$pb.TagNumber(4)
  set requestId($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasRequestId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequestId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get ts => $_getSZ(4);
  @$pb.TagNumber(5)
  set ts($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasTs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get authorization => $_getSZ(5);
  @$pb.TagNumber(6)
  set authorization($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasAuthorization() => $_has(5);
  @$pb.TagNumber(6)
  void clearAuthorization() => $_clearField(6);
}

class SetRequestMessage extends $pb.GeneratedMessage {
  factory SetRequestMessage({
    $core.String? path,
    $core.String? value,
    $core.String? authorization,
    $core.String? requestId,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    if (value != null) {
      $result.value = value;
    }
    if (authorization != null) {
      $result.authorization = authorization;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    return $result;
  }
  SetRequestMessage._() : super();
  factory SetRequestMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SetRequestMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetRequestMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Path', protoName: 'Path')
    ..aOS(2, _omitFieldNames ? '' : 'Value', protoName: 'Value')
    ..aOS(3, _omitFieldNames ? '' : 'Authorization', protoName: 'Authorization')
    ..aOS(4, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRequestMessage clone() => SetRequestMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRequestMessage copyWith(void Function(SetRequestMessage) updates) =>
      super.copyWith((message) => updates(message as SetRequestMessage))
          as SetRequestMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetRequestMessage create() => SetRequestMessage._();
  SetRequestMessage createEmptyInstance() => create();
  static $pb.PbList<SetRequestMessage> createRepeated() =>
      $pb.PbList<SetRequestMessage>();
  @$core.pragma('dart2js:noInline')
  static SetRequestMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetRequestMessage>(create);
  static SetRequestMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get value => $_getSZ(1);
  @$pb.TagNumber(2)
  set value($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get authorization => $_getSZ(2);
  @$pb.TagNumber(3)
  set authorization($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasAuthorization() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthorization() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get requestId => $_getSZ(3);
  @$pb.TagNumber(4)
  set requestId($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasRequestId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequestId() => $_clearField(4);
}

class SetResponseMessage extends $pb.GeneratedMessage {
  factory SetResponseMessage({
    ResponseStatus? status,
    ErrorResponseMessage? errorResponse,
    $core.String? requestId,
    $core.String? ts,
    $core.String? authorization,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (errorResponse != null) {
      $result.errorResponse = errorResponse;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    if (authorization != null) {
      $result.authorization = authorization;
    }
    return $result;
  }
  SetResponseMessage._() : super();
  factory SetResponseMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SetResponseMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..e<ResponseStatus>(1, _omitFieldNames ? '' : 'Status', $pb.PbFieldType.OE,
        protoName: 'Status',
        defaultOrMaker: ResponseStatus.SUCCESS,
        valueOf: ResponseStatus.valueOf,
        enumValues: ResponseStatus.values)
    ..aOM<ErrorResponseMessage>(2, _omitFieldNames ? '' : 'ErrorResponse',
        protoName: 'ErrorResponse', subBuilder: ErrorResponseMessage.create)
    ..aOS(3, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..aOS(4, _omitFieldNames ? '' : 'Ts', protoName: 'Ts')
    ..aOS(5, _omitFieldNames ? '' : 'Authorization', protoName: 'Authorization')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetResponseMessage clone() => SetResponseMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetResponseMessage copyWith(void Function(SetResponseMessage) updates) =>
      super.copyWith((message) => updates(message as SetResponseMessage))
          as SetResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetResponseMessage create() => SetResponseMessage._();
  SetResponseMessage createEmptyInstance() => create();
  static $pb.PbList<SetResponseMessage> createRepeated() =>
      $pb.PbList<SetResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static SetResponseMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetResponseMessage>(create);
  static SetResponseMessage? _defaultInstance;

  @$pb.TagNumber(1)
  ResponseStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(ResponseStatus v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  ErrorResponseMessage get errorResponse => $_getN(1);
  @$pb.TagNumber(2)
  set errorResponse(ErrorResponseMessage v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasErrorResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  ErrorResponseMessage ensureErrorResponse() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get ts => $_getSZ(3);
  @$pb.TagNumber(4)
  set ts($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasTs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get authorization => $_getSZ(4);
  @$pb.TagNumber(5)
  set authorization($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasAuthorization() => $_has(4);
  @$pb.TagNumber(5)
  void clearAuthorization() => $_clearField(5);
}

class SubscribeRequestMessage extends $pb.GeneratedMessage {
  factory SubscribeRequestMessage({
    $core.String? path,
    FilterExpressions? filter,
    $core.String? authorization,
    $core.String? dataCompression,
    $core.String? requestId,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    if (filter != null) {
      $result.filter = filter;
    }
    if (authorization != null) {
      $result.authorization = authorization;
    }
    if (dataCompression != null) {
      $result.dataCompression = dataCompression;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    return $result;
  }
  SubscribeRequestMessage._() : super();
  factory SubscribeRequestMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SubscribeRequestMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeRequestMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Path', protoName: 'Path')
    ..aOM<FilterExpressions>(2, _omitFieldNames ? '' : 'Filter',
        protoName: 'Filter', subBuilder: FilterExpressions.create)
    ..aOS(3, _omitFieldNames ? '' : 'Authorization', protoName: 'Authorization')
    ..aOS(4, _omitFieldNames ? '' : 'DataCompression',
        protoName: 'DataCompression')
    ..aOS(5, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeRequestMessage clone() =>
      SubscribeRequestMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeRequestMessage copyWith(
          void Function(SubscribeRequestMessage) updates) =>
      super.copyWith((message) => updates(message as SubscribeRequestMessage))
          as SubscribeRequestMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeRequestMessage create() => SubscribeRequestMessage._();
  SubscribeRequestMessage createEmptyInstance() => create();
  static $pb.PbList<SubscribeRequestMessage> createRepeated() =>
      $pb.PbList<SubscribeRequestMessage>();
  @$core.pragma('dart2js:noInline')
  static SubscribeRequestMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscribeRequestMessage>(create);
  static SubscribeRequestMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  FilterExpressions get filter => $_getN(1);
  @$pb.TagNumber(2)
  set filter(FilterExpressions v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasFilter() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilter() => $_clearField(2);
  @$pb.TagNumber(2)
  FilterExpressions ensureFilter() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get authorization => $_getSZ(2);
  @$pb.TagNumber(3)
  set authorization($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasAuthorization() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthorization() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get dataCompression => $_getSZ(3);
  @$pb.TagNumber(4)
  set dataCompression($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasDataCompression() => $_has(3);
  @$pb.TagNumber(4)
  void clearDataCompression() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get requestId => $_getSZ(4);
  @$pb.TagNumber(5)
  set requestId($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasRequestId() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestId() => $_clearField(5);
}

class SubscribeStreamMessage_SubscribeResponseMessage
    extends $pb.GeneratedMessage {
  factory SubscribeStreamMessage_SubscribeResponseMessage({
    ErrorResponseMessage? errorResponse,
    $core.String? subscriptionId,
    $core.String? requestId,
    $core.String? ts,
    $core.String? authorization,
  }) {
    final $result = create();
    if (errorResponse != null) {
      $result.errorResponse = errorResponse;
    }
    if (subscriptionId != null) {
      $result.subscriptionId = subscriptionId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    if (authorization != null) {
      $result.authorization = authorization;
    }
    return $result;
  }
  SubscribeStreamMessage_SubscribeResponseMessage._() : super();
  factory SubscribeStreamMessage_SubscribeResponseMessage.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SubscribeStreamMessage_SubscribeResponseMessage.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'SubscribeStreamMessage.SubscribeResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOM<ErrorResponseMessage>(1, _omitFieldNames ? '' : 'ErrorResponse',
        protoName: 'ErrorResponse', subBuilder: ErrorResponseMessage.create)
    ..aOS(2, _omitFieldNames ? '' : 'SubscriptionId',
        protoName: 'SubscriptionId')
    ..aOS(3, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..aOS(4, _omitFieldNames ? '' : 'Ts', protoName: 'Ts')
    ..aOS(5, _omitFieldNames ? '' : 'Authorization', protoName: 'Authorization')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage_SubscribeResponseMessage clone() =>
      SubscribeStreamMessage_SubscribeResponseMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage_SubscribeResponseMessage copyWith(
          void Function(SubscribeStreamMessage_SubscribeResponseMessage)
              updates) =>
      super.copyWith((message) => updates(
              message as SubscribeStreamMessage_SubscribeResponseMessage))
          as SubscribeStreamMessage_SubscribeResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage_SubscribeResponseMessage create() =>
      SubscribeStreamMessage_SubscribeResponseMessage._();
  SubscribeStreamMessage_SubscribeResponseMessage createEmptyInstance() =>
      create();
  static $pb.PbList<SubscribeStreamMessage_SubscribeResponseMessage>
      createRepeated() =>
          $pb.PbList<SubscribeStreamMessage_SubscribeResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage_SubscribeResponseMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          SubscribeStreamMessage_SubscribeResponseMessage>(create);
  static SubscribeStreamMessage_SubscribeResponseMessage? _defaultInstance;

  @$pb.TagNumber(1)
  ErrorResponseMessage get errorResponse => $_getN(0);
  @$pb.TagNumber(1)
  set errorResponse(ErrorResponseMessage v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasErrorResponse() => $_has(0);
  @$pb.TagNumber(1)
  void clearErrorResponse() => $_clearField(1);
  @$pb.TagNumber(1)
  ErrorResponseMessage ensureErrorResponse() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get subscriptionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set subscriptionId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasSubscriptionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubscriptionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get ts => $_getSZ(3);
  @$pb.TagNumber(4)
  set ts($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasTs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTs() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get authorization => $_getSZ(4);
  @$pb.TagNumber(5)
  set authorization($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasAuthorization() => $_has(4);
  @$pb.TagNumber(5)
  void clearAuthorization() => $_clearField(5);
}

class SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
    extends $pb.GeneratedMessage {
  factory SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage({
    DataPackages? dataPack,
  }) {
    final $result = create();
    if (dataPack != null) {
      $result.dataPack = dataPack;
    }
    return $result;
  }
  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage._()
      : super();
  factory SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage.fromJson(
          $core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames
          ? ''
          : 'SubscribeStreamMessage.SubscribeEventMessage.SuccessResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOM<DataPackages>(1, _omitFieldNames ? '' : 'DataPack',
        protoName: 'DataPack', subBuilder: DataPackages.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage clone() =>
      SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage()
        ..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage copyWith(
          void Function(
                  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage)
              updates) =>
      super.copyWith((message) => updates(message
              as SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage))
          as SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
      create() =>
          SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
              ._();
  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
      createEmptyInstance() => create();
  static $pb.PbList<
          SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage>
      createRepeated() => $pb.PbList<
          SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
      getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage>(
          create);
  static SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage?
      _defaultInstance;

  @$pb.TagNumber(1)
  DataPackages get dataPack => $_getN(0);
  @$pb.TagNumber(1)
  set dataPack(DataPackages v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasDataPack() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataPack() => $_clearField(1);
  @$pb.TagNumber(1)
  DataPackages ensureDataPack() => $_ensure(0);
}

class SubscribeStreamMessage_SubscribeEventMessage
    extends $pb.GeneratedMessage {
  factory SubscribeStreamMessage_SubscribeEventMessage({
    $core.String? subscriptionId,
    SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage?
        successResponse,
    ErrorResponseMessage? errorResponse,
    $core.String? ts,
  }) {
    final $result = create();
    if (subscriptionId != null) {
      $result.subscriptionId = subscriptionId;
    }
    if (successResponse != null) {
      $result.successResponse = successResponse;
    }
    if (errorResponse != null) {
      $result.errorResponse = errorResponse;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    return $result;
  }
  SubscribeStreamMessage_SubscribeEventMessage._() : super();
  factory SubscribeStreamMessage_SubscribeEventMessage.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SubscribeStreamMessage_SubscribeEventMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeStreamMessage.SubscribeEventMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'SubscriptionId',
        protoName: 'SubscriptionId')
    ..aOM<SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage>(
        2, _omitFieldNames ? '' : 'SuccessResponse',
        protoName: 'SuccessResponse',
        subBuilder:
            SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
                .create)
    ..aOM<ErrorResponseMessage>(3, _omitFieldNames ? '' : 'ErrorResponse',
        protoName: 'ErrorResponse', subBuilder: ErrorResponseMessage.create)
    ..aOS(4, _omitFieldNames ? '' : 'Ts', protoName: 'Ts')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage_SubscribeEventMessage clone() =>
      SubscribeStreamMessage_SubscribeEventMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage_SubscribeEventMessage copyWith(
          void Function(SubscribeStreamMessage_SubscribeEventMessage)
              updates) =>
      super.copyWith((message) =>
              updates(message as SubscribeStreamMessage_SubscribeEventMessage))
          as SubscribeStreamMessage_SubscribeEventMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage_SubscribeEventMessage create() =>
      SubscribeStreamMessage_SubscribeEventMessage._();
  SubscribeStreamMessage_SubscribeEventMessage createEmptyInstance() =>
      create();
  static $pb.PbList<SubscribeStreamMessage_SubscribeEventMessage>
      createRepeated() =>
          $pb.PbList<SubscribeStreamMessage_SubscribeEventMessage>();
  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage_SubscribeEventMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          SubscribeStreamMessage_SubscribeEventMessage>(create);
  static SubscribeStreamMessage_SubscribeEventMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get subscriptionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set subscriptionId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSubscriptionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscriptionId() => $_clearField(1);

  @$pb.TagNumber(2)
  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
      get successResponse => $_getN(1);
  @$pb.TagNumber(2)
  set successResponse(
      SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasSuccessResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearSuccessResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage
      ensureSuccessResponse() => $_ensure(1);

  @$pb.TagNumber(3)
  ErrorResponseMessage get errorResponse => $_getN(2);
  @$pb.TagNumber(3)
  set errorResponse(ErrorResponseMessage v) {
    $_setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasErrorResponse() => $_has(2);
  @$pb.TagNumber(3)
  void clearErrorResponse() => $_clearField(3);
  @$pb.TagNumber(3)
  ErrorResponseMessage ensureErrorResponse() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get ts => $_getSZ(3);
  @$pb.TagNumber(4)
  set ts($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasTs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTs() => $_clearField(4);
}

class SubscribeStreamMessage extends $pb.GeneratedMessage {
  factory SubscribeStreamMessage({
    SubscribeResponseType? mType,
    ResponseStatus? status,
    SubscribeStreamMessage_SubscribeResponseMessage? response,
    SubscribeStreamMessage_SubscribeEventMessage? event,
  }) {
    final $result = create();
    if (mType != null) {
      $result.mType = mType;
    }
    if (status != null) {
      $result.status = status;
    }
    if (response != null) {
      $result.response = response;
    }
    if (event != null) {
      $result.event = event;
    }
    return $result;
  }
  SubscribeStreamMessage._() : super();
  factory SubscribeStreamMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SubscribeStreamMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeStreamMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..e<SubscribeResponseType>(
        1, _omitFieldNames ? '' : 'MType', $pb.PbFieldType.OE,
        protoName: 'MType',
        defaultOrMaker: SubscribeResponseType.RESPONSE,
        valueOf: SubscribeResponseType.valueOf,
        enumValues: SubscribeResponseType.values)
    ..e<ResponseStatus>(2, _omitFieldNames ? '' : 'Status', $pb.PbFieldType.OE,
        protoName: 'Status',
        defaultOrMaker: ResponseStatus.SUCCESS,
        valueOf: ResponseStatus.valueOf,
        enumValues: ResponseStatus.values)
    ..aOM<SubscribeStreamMessage_SubscribeResponseMessage>(
        3, _omitFieldNames ? '' : 'Response',
        protoName: 'Response',
        subBuilder: SubscribeStreamMessage_SubscribeResponseMessage.create)
    ..aOM<SubscribeStreamMessage_SubscribeEventMessage>(
        4, _omitFieldNames ? '' : 'Event',
        protoName: 'Event',
        subBuilder: SubscribeStreamMessage_SubscribeEventMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage clone() =>
      SubscribeStreamMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeStreamMessage copyWith(
          void Function(SubscribeStreamMessage) updates) =>
      super.copyWith((message) => updates(message as SubscribeStreamMessage))
          as SubscribeStreamMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage create() => SubscribeStreamMessage._();
  SubscribeStreamMessage createEmptyInstance() => create();
  static $pb.PbList<SubscribeStreamMessage> createRepeated() =>
      $pb.PbList<SubscribeStreamMessage>();
  @$core.pragma('dart2js:noInline')
  static SubscribeStreamMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscribeStreamMessage>(create);
  static SubscribeStreamMessage? _defaultInstance;

  @$pb.TagNumber(1)
  SubscribeResponseType get mType => $_getN(0);
  @$pb.TagNumber(1)
  set mType(SubscribeResponseType v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMType() => $_clearField(1);

  @$pb.TagNumber(2)
  ResponseStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(ResponseStatus v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  SubscribeStreamMessage_SubscribeResponseMessage get response => $_getN(2);
  @$pb.TagNumber(3)
  set response(SubscribeStreamMessage_SubscribeResponseMessage v) {
    $_setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasResponse() => $_has(2);
  @$pb.TagNumber(3)
  void clearResponse() => $_clearField(3);
  @$pb.TagNumber(3)
  SubscribeStreamMessage_SubscribeResponseMessage ensureResponse() =>
      $_ensure(2);

  @$pb.TagNumber(4)
  SubscribeStreamMessage_SubscribeEventMessage get event => $_getN(3);
  @$pb.TagNumber(4)
  set event(SubscribeStreamMessage_SubscribeEventMessage v) {
    $_setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasEvent() => $_has(3);
  @$pb.TagNumber(4)
  void clearEvent() => $_clearField(4);
  @$pb.TagNumber(4)
  SubscribeStreamMessage_SubscribeEventMessage ensureEvent() => $_ensure(3);
}

class UnsubscribeRequestMessage extends $pb.GeneratedMessage {
  factory UnsubscribeRequestMessage({
    $core.String? subscriptionId,
    $core.String? requestId,
  }) {
    final $result = create();
    if (subscriptionId != null) {
      $result.subscriptionId = subscriptionId;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    return $result;
  }
  UnsubscribeRequestMessage._() : super();
  factory UnsubscribeRequestMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory UnsubscribeRequestMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnsubscribeRequestMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'SubscriptionId',
        protoName: 'SubscriptionId')
    ..aOS(2, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnsubscribeRequestMessage clone() =>
      UnsubscribeRequestMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnsubscribeRequestMessage copyWith(
          void Function(UnsubscribeRequestMessage) updates) =>
      super.copyWith((message) => updates(message as UnsubscribeRequestMessage))
          as UnsubscribeRequestMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnsubscribeRequestMessage create() => UnsubscribeRequestMessage._();
  UnsubscribeRequestMessage createEmptyInstance() => create();
  static $pb.PbList<UnsubscribeRequestMessage> createRepeated() =>
      $pb.PbList<UnsubscribeRequestMessage>();
  @$core.pragma('dart2js:noInline')
  static UnsubscribeRequestMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnsubscribeRequestMessage>(create);
  static UnsubscribeRequestMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get subscriptionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set subscriptionId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSubscriptionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSubscriptionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);
}

class UnsubscribeResponseMessage extends $pb.GeneratedMessage {
  factory UnsubscribeResponseMessage({
    ResponseStatus? status,
    ErrorResponseMessage? errorResponse,
    $core.String? requestId,
    $core.String? ts,
  }) {
    final $result = create();
    if (status != null) {
      $result.status = status;
    }
    if (errorResponse != null) {
      $result.errorResponse = errorResponse;
    }
    if (requestId != null) {
      $result.requestId = requestId;
    }
    if (ts != null) {
      $result.ts = ts;
    }
    return $result;
  }
  UnsubscribeResponseMessage._() : super();
  factory UnsubscribeResponseMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory UnsubscribeResponseMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnsubscribeResponseMessage',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'grpcProtobufMessages'),
      createEmptyInstance: create)
    ..e<ResponseStatus>(1, _omitFieldNames ? '' : 'Status', $pb.PbFieldType.OE,
        protoName: 'Status',
        defaultOrMaker: ResponseStatus.SUCCESS,
        valueOf: ResponseStatus.valueOf,
        enumValues: ResponseStatus.values)
    ..aOM<ErrorResponseMessage>(2, _omitFieldNames ? '' : 'ErrorResponse',
        protoName: 'ErrorResponse', subBuilder: ErrorResponseMessage.create)
    ..aOS(3, _omitFieldNames ? '' : 'RequestId', protoName: 'RequestId')
    ..aOS(4, _omitFieldNames ? '' : 'Ts', protoName: 'Ts')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnsubscribeResponseMessage clone() =>
      UnsubscribeResponseMessage()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnsubscribeResponseMessage copyWith(
          void Function(UnsubscribeResponseMessage) updates) =>
      super.copyWith(
              (message) => updates(message as UnsubscribeResponseMessage))
          as UnsubscribeResponseMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnsubscribeResponseMessage create() => UnsubscribeResponseMessage._();
  UnsubscribeResponseMessage createEmptyInstance() => create();
  static $pb.PbList<UnsubscribeResponseMessage> createRepeated() =>
      $pb.PbList<UnsubscribeResponseMessage>();
  @$core.pragma('dart2js:noInline')
  static UnsubscribeResponseMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnsubscribeResponseMessage>(create);
  static UnsubscribeResponseMessage? _defaultInstance;

  @$pb.TagNumber(1)
  ResponseStatus get status => $_getN(0);
  @$pb.TagNumber(1)
  set status(ResponseStatus v) {
    $_setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  ErrorResponseMessage get errorResponse => $_getN(1);
  @$pb.TagNumber(2)
  set errorResponse(ErrorResponseMessage v) {
    $_setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasErrorResponse() => $_has(1);
  @$pb.TagNumber(2)
  void clearErrorResponse() => $_clearField(2);
  @$pb.TagNumber(2)
  ErrorResponseMessage ensureErrorResponse() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get requestId => $_getSZ(2);
  @$pb.TagNumber(3)
  set requestId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRequestId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get ts => $_getSZ(3);
  @$pb.TagNumber(4)
  set ts($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasTs() => $_has(3);
  @$pb.TagNumber(4)
  void clearTs() => $_clearField(4);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
