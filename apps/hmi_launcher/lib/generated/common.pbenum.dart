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

///  -----------------------------------------------------------------------------
///  IntentKind
///
///  Mirrors ai_command::RouteResult::Kind:
///    ToolCall -> INTENT_TOOL
///    Chat     -> INTENT_CHAT
///    Unknown  -> INTENT_UNKNOWN
///  -----------------------------------------------------------------------------
class IntentKind extends $pb.ProtobufEnum {
  static const IntentKind INTENT_UNKNOWN = IntentKind._(0, _omitEnumNames ? '' : 'INTENT_UNKNOWN');
  static const IntentKind INTENT_TOOL = IntentKind._(1, _omitEnumNames ? '' : 'INTENT_TOOL');
  static const IntentKind INTENT_CHAT = IntentKind._(2, _omitEnumNames ? '' : 'INTENT_CHAT');

  static const $core.List<IntentKind> values = <IntentKind> [
    INTENT_UNKNOWN,
    INTENT_TOOL,
    INTENT_CHAT,
  ];

  static final $core.Map<$core.int, IntentKind> _byValue = $pb.ProtobufEnum.initByValue(values);
  static IntentKind? valueOf($core.int value) => _byValue[value];

  const IntentKind._($core.int v, $core.String n) : super(v, n);
}

///  -----------------------------------------------------------------------------
///  CommandExecutionState
///
///  Stable app-facing state for command / voice command results. This lets
///  clients drive UX without inferring from combinations of booleans.
///  -----------------------------------------------------------------------------
class CommandExecutionState extends $pb.ProtobufEnum {
  static const CommandExecutionState COMMAND_EXECUTION_STATE_UNSPECIFIED = CommandExecutionState._(0, _omitEnumNames ? '' : 'COMMAND_EXECUTION_STATE_UNSPECIFIED');
  static const CommandExecutionState COMMAND_EXECUTION_PENDING_CONFIRMATION = CommandExecutionState._(1, _omitEnumNames ? '' : 'COMMAND_EXECUTION_PENDING_CONFIRMATION');
  static const CommandExecutionState COMMAND_EXECUTION_EXECUTED = CommandExecutionState._(2, _omitEnumNames ? '' : 'COMMAND_EXECUTION_EXECUTED');
  static const CommandExecutionState COMMAND_EXECUTION_CANCELLED = CommandExecutionState._(3, _omitEnumNames ? '' : 'COMMAND_EXECUTION_CANCELLED');
  static const CommandExecutionState COMMAND_EXECUTION_REJECTED = CommandExecutionState._(4, _omitEnumNames ? '' : 'COMMAND_EXECUTION_REJECTED');
  static const CommandExecutionState COMMAND_EXECUTION_FAILED = CommandExecutionState._(5, _omitEnumNames ? '' : 'COMMAND_EXECUTION_FAILED');
  static const CommandExecutionState COMMAND_EXECUTION_CHAT = CommandExecutionState._(6, _omitEnumNames ? '' : 'COMMAND_EXECUTION_CHAT');
  static const CommandExecutionState COMMAND_EXECUTION_UNKNOWN = CommandExecutionState._(7, _omitEnumNames ? '' : 'COMMAND_EXECUTION_UNKNOWN');

  static const $core.List<CommandExecutionState> values = <CommandExecutionState> [
    COMMAND_EXECUTION_STATE_UNSPECIFIED,
    COMMAND_EXECUTION_PENDING_CONFIRMATION,
    COMMAND_EXECUTION_EXECUTED,
    COMMAND_EXECUTION_CANCELLED,
    COMMAND_EXECUTION_REJECTED,
    COMMAND_EXECUTION_FAILED,
    COMMAND_EXECUTION_CHAT,
    COMMAND_EXECUTION_UNKNOWN,
  ];

  static final $core.Map<$core.int, CommandExecutionState> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CommandExecutionState? valueOf($core.int value) => _byValue[value];

  const CommandExecutionState._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
