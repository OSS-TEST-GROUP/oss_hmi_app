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

class ResponseStatus extends $pb.ProtobufEnum {
  static const ResponseStatus SUCCESS =
      ResponseStatus._(0, _omitEnumNames ? '' : 'SUCCESS');
  static const ResponseStatus ERROR =
      ResponseStatus._(1, _omitEnumNames ? '' : 'ERROR');

  static const $core.List<ResponseStatus> values = <ResponseStatus>[
    SUCCESS,
    ERROR,
  ];

  static final $core.List<ResponseStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ResponseStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ResponseStatus._(super.v, super.n);
}

class SubscribeResponseType extends $pb.ProtobufEnum {
  static const SubscribeResponseType RESPONSE =
      SubscribeResponseType._(0, _omitEnumNames ? '' : 'RESPONSE');
  static const SubscribeResponseType EVENT =
      SubscribeResponseType._(1, _omitEnumNames ? '' : 'EVENT');

  static const $core.List<SubscribeResponseType> values =
      <SubscribeResponseType>[
    RESPONSE,
    EVENT,
  ];

  static final $core.List<SubscribeResponseType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static SubscribeResponseType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SubscribeResponseType._(super.v, super.n);
}

class FilterExpressions_FilterExpression_FilterVariant
    extends $pb.ProtobufEnum {
  static const FilterExpressions_FilterExpression_FilterVariant PATHS =
      FilterExpressions_FilterExpression_FilterVariant._(
          0, _omitEnumNames ? '' : 'PATHS');
  static const FilterExpressions_FilterExpression_FilterVariant TIMEBASED =
      FilterExpressions_FilterExpression_FilterVariant._(
          1, _omitEnumNames ? '' : 'TIMEBASED');
  static const FilterExpressions_FilterExpression_FilterVariant RANGE =
      FilterExpressions_FilterExpression_FilterVariant._(
          2, _omitEnumNames ? '' : 'RANGE');
  static const FilterExpressions_FilterExpression_FilterVariant CHANGE =
      FilterExpressions_FilterExpression_FilterVariant._(
          3, _omitEnumNames ? '' : 'CHANGE');
  static const FilterExpressions_FilterExpression_FilterVariant CURVELOG =
      FilterExpressions_FilterExpression_FilterVariant._(
          4, _omitEnumNames ? '' : 'CURVELOG');
  static const FilterExpressions_FilterExpression_FilterVariant HISTORY =
      FilterExpressions_FilterExpression_FilterVariant._(
          5, _omitEnumNames ? '' : 'HISTORY');
  static const FilterExpressions_FilterExpression_FilterVariant METADATA =
      FilterExpressions_FilterExpression_FilterVariant._(
          6, _omitEnumNames ? '' : 'METADATA');

  static const $core.List<FilterExpressions_FilterExpression_FilterVariant>
      values = <FilterExpressions_FilterExpression_FilterVariant>[
    PATHS,
    TIMEBASED,
    RANGE,
    CHANGE,
    CURVELOG,
    HISTORY,
    METADATA,
  ];

  static final $core.List<FilterExpressions_FilterExpression_FilterVariant?>
      _byValue = $pb.ProtobufEnum.$_initByValueList(values, 6);
  static FilterExpressions_FilterExpression_FilterVariant? valueOf(
          $core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FilterExpressions_FilterExpression_FilterVariant._(super.v, super.n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
