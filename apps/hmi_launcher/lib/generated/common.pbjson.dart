//
//  Generated code. Do not modify.
//  source: common.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use intentKindDescriptor instead')
const IntentKind$json = {
  '1': 'IntentKind',
  '2': [
    {'1': 'INTENT_UNKNOWN', '2': 0},
    {'1': 'INTENT_TOOL', '2': 1},
    {'1': 'INTENT_CHAT', '2': 2},
  ],
};

/// Descriptor for `IntentKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List intentKindDescriptor = $convert.base64Decode(
    'CgpJbnRlbnRLaW5kEhIKDklOVEVOVF9VTktOT1dOEAASDwoLSU5URU5UX1RPT0wQARIPCgtJTl'
    'RFTlRfQ0hBVBAC');

@$core.Deprecated('Use commandExecutionStateDescriptor instead')
const CommandExecutionState$json = {
  '1': 'CommandExecutionState',
  '2': [
    {'1': 'COMMAND_EXECUTION_STATE_UNSPECIFIED', '2': 0},
    {'1': 'COMMAND_EXECUTION_PENDING_CONFIRMATION', '2': 1},
    {'1': 'COMMAND_EXECUTION_EXECUTED', '2': 2},
    {'1': 'COMMAND_EXECUTION_CANCELLED', '2': 3},
    {'1': 'COMMAND_EXECUTION_REJECTED', '2': 4},
    {'1': 'COMMAND_EXECUTION_FAILED', '2': 5},
    {'1': 'COMMAND_EXECUTION_CHAT', '2': 6},
    {'1': 'COMMAND_EXECUTION_UNKNOWN', '2': 7},
  ],
};

/// Descriptor for `CommandExecutionState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List commandExecutionStateDescriptor = $convert.base64Decode(
    'ChVDb21tYW5kRXhlY3V0aW9uU3RhdGUSJwojQ09NTUFORF9FWEVDVVRJT05fU1RBVEVfVU5TUE'
    'VDSUZJRUQQABIqCiZDT01NQU5EX0VYRUNVVElPTl9QRU5ESU5HX0NPTkZJUk1BVElPThABEh4K'
    'GkNPTU1BTkRfRVhFQ1VUSU9OX0VYRUNVVEVEEAISHwobQ09NTUFORF9FWEVDVVRJT05fQ0FOQ0'
    'VMTEVEEAMSHgoaQ09NTUFORF9FWEVDVVRJT05fUkVKRUNURUQQBBIcChhDT01NQU5EX0VYRUNV'
    'VElPTl9GQUlMRUQQBRIaChZDT01NQU5EX0VYRUNVVElPTl9DSEFUEAYSHQoZQ09NTUFORF9FWE'
    'VDVVRJT05fVU5LTk9XThAH');

@$core.Deprecated('Use metricSetDescriptor instead')
const MetricSet$json = {
  '1': 'MetricSet',
  '2': [
    {'1': 'stt_ms', '3': 1, '4': 1, '5': 1, '10': 'sttMs'},
    {'1': 'router_ms', '3': 2, '4': 1, '5': 1, '10': 'routerMs'},
    {'1': 'llm_ttft_ms', '3': 3, '4': 1, '5': 1, '10': 'llmTtftMs'},
    {'1': 'llm_ms', '3': 4, '4': 1, '5': 1, '10': 'llmMs'},
    {'1': 'tool_ms', '3': 5, '4': 1, '5': 1, '10': 'toolMs'},
    {'1': 'safety_ms', '3': 6, '4': 1, '5': 1, '10': 'safetyMs'},
    {'1': 'perceived_ms', '3': 7, '4': 1, '5': 1, '10': 'perceivedMs'},
    {'1': 'total_ms', '3': 8, '4': 1, '5': 1, '10': 'totalMs'},
  ],
};

/// Descriptor for `MetricSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List metricSetDescriptor = $convert.base64Decode(
    'CglNZXRyaWNTZXQSFQoGc3R0X21zGAEgASgBUgVzdHRNcxIbCglyb3V0ZXJfbXMYAiABKAFSCH'
    'JvdXRlck1zEh4KC2xsbV90dGZ0X21zGAMgASgBUglsbG1UdGZ0TXMSFQoGbGxtX21zGAQgASgB'
    'UgVsbG1NcxIXCgd0b29sX21zGAUgASgBUgZ0b29sTXMSGwoJc2FmZXR5X21zGAYgASgBUghzYW'
    'ZldHlNcxIhCgxwZXJjZWl2ZWRfbXMYByABKAFSC3BlcmNlaXZlZE1zEhkKCHRvdGFsX21zGAgg'
    'ASgBUgd0b3RhbE1z');

@$core.Deprecated('Use pipelineInfoDescriptor instead')
const PipelineInfo$json = {
  '1': 'PipelineInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'tags', '3': 4, '4': 3, '5': 9, '10': 'tags'},
    {'1': 'metadata', '3': 5, '4': 3, '5': 11, '6': '.oais.common.v1.PipelineInfo.MetadataEntry', '10': 'metadata'},
  ],
  '3': [PipelineInfo_MetadataEntry$json],
};

@$core.Deprecated('Use pipelineInfoDescriptor instead')
const PipelineInfo_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `PipelineInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pipelineInfoDescriptor = $convert.base64Decode(
    'CgxQaXBlbGluZUluZm8SDgoCaWQYASABKAlSAmlkEhIKBGtpbmQYAiABKAlSBGtpbmQSIAoLZG'
    'VzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhIKBHRhZ3MYBCADKAlSBHRhZ3MSRgoIbWV0'
    'YWRhdGEYBSADKAsyKi5vYWlzLmNvbW1vbi52MS5QaXBlbGluZUluZm8uTWV0YWRhdGFFbnRyeV'
    'IIbWV0YWRhdGEaOwoNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgC'
    'IAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use audioFormatDescriptor instead')
const AudioFormat$json = {
  '1': 'AudioFormat',
  '2': [
    {'1': 'sample_rate_hz', '3': 1, '4': 1, '5': 13, '10': 'sampleRateHz'},
    {'1': 'channels', '3': 2, '4': 1, '5': 13, '10': 'channels'},
    {'1': 'encoding', '3': 3, '4': 1, '5': 9, '10': 'encoding'},
  ],
};

/// Descriptor for `AudioFormat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioFormatDescriptor = $convert.base64Decode(
    'CgtBdWRpb0Zvcm1hdBIkCg5zYW1wbGVfcmF0ZV9oehgBIAEoDVIMc2FtcGxlUmF0ZUh6EhoKCG'
    'NoYW5uZWxzGAIgASgNUghjaGFubmVscxIaCghlbmNvZGluZxgDIAEoCVIIZW5jb2Rpbmc=');

@$core.Deprecated('Use audioChunkDescriptor instead')
const AudioChunk$json = {
  '1': 'AudioChunk',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'pipeline_id', '3': 2, '4': 1, '5': 9, '10': 'pipelineId'},
    {'1': 'format', '3': 3, '4': 1, '5': 11, '6': '.oais.common.v1.AudioFormat', '10': 'format'},
    {'1': 'audio', '3': 4, '4': 1, '5': 12, '10': 'audio'},
    {'1': 'end_of_stream', '3': 5, '4': 1, '5': 8, '10': 'endOfStream'},
  ],
};

/// Descriptor for `AudioChunk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioChunkDescriptor = $convert.base64Decode(
    'CgpBdWRpb0NodW5rEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIfCgtwaXBlbGluZV'
    '9pZBgCIAEoCVIKcGlwZWxpbmVJZBIzCgZmb3JtYXQYAyABKAsyGy5vYWlzLmNvbW1vbi52MS5B'
    'dWRpb0Zvcm1hdFIGZm9ybWF0EhQKBWF1ZGlvGAQgASgMUgVhdWRpbxIiCg1lbmRfb2Zfc3RyZW'
    'FtGAUgASgIUgtlbmRPZlN0cmVhbQ==');

@$core.Deprecated('Use stageTraceDescriptor instead')
const StageTrace$json = {
  '1': 'StageTrace',
  '2': [
    {'1': 'stage_name', '3': 1, '4': 1, '5': 9, '10': 'stageName'},
    {'1': 'classifier_name', '3': 2, '4': 1, '5': 9, '10': 'classifierName'},
    {'1': 'intent', '3': 3, '4': 1, '5': 14, '6': '.oais.common.v1.IntentKind', '10': 'intent'},
    {'1': 'tool_name', '3': 4, '4': 1, '5': 9, '10': 'toolName'},
    {'1': 'confidence', '3': 5, '4': 1, '5': 1, '10': 'confidence'},
    {'1': 'raw_json', '3': 6, '4': 1, '5': 9, '10': 'rawJson'},
  ],
};

/// Descriptor for `StageTrace`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stageTraceDescriptor = $convert.base64Decode(
    'CgpTdGFnZVRyYWNlEh0KCnN0YWdlX25hbWUYASABKAlSCXN0YWdlTmFtZRInCg9jbGFzc2lmaW'
    'VyX25hbWUYAiABKAlSDmNsYXNzaWZpZXJOYW1lEjIKBmludGVudBgDIAEoDjIaLm9haXMuY29t'
    'bW9uLnYxLkludGVudEtpbmRSBmludGVudBIbCgl0b29sX25hbWUYBCABKAlSCHRvb2xOYW1lEh'
    '4KCmNvbmZpZGVuY2UYBSABKAFSCmNvbmZpZGVuY2USGQoIcmF3X2pzb24YBiABKAlSB3Jhd0pz'
    'b24=');

