//
//  Generated code. Do not modify.
//  source: agent.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// ActionType — CardAction 처리 방식 분류.
class ActionType extends $pb.ProtobufEnum {
  static const ActionType ACTION_TYPE_UNSPECIFIED = ActionType._(0, _omitEnumNames ? '' : 'ACTION_TYPE_UNSPECIFIED');
  static const ActionType ACTION_TYPE_CONFIRM = ActionType._(1, _omitEnumNames ? '' : 'ACTION_TYPE_CONFIRM');
  static const ActionType ACTION_TYPE_DISMISS = ActionType._(2, _omitEnumNames ? '' : 'ACTION_TYPE_DISMISS');
  static const ActionType ACTION_TYPE_OPEN_APP = ActionType._(3, _omitEnumNames ? '' : 'ACTION_TYPE_OPEN_APP');

  static const $core.List<ActionType> values = <ActionType> [
    ACTION_TYPE_UNSPECIFIED,
    ACTION_TYPE_CONFIRM,
    ACTION_TYPE_DISMISS,
    ACTION_TYPE_OPEN_APP,
  ];

  static final $core.Map<$core.int, ActionType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ActionType? valueOf($core.int value) => _byValue[value];

  const ActionType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
