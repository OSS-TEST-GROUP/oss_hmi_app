//
//  Generated code. Do not modify.
//  source: agent.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use actionTypeDescriptor instead')
const ActionType$json = {
  '1': 'ActionType',
  '2': [
    {'1': 'ACTION_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ACTION_TYPE_CONFIRM', '2': 1},
    {'1': 'ACTION_TYPE_DISMISS', '2': 2},
    {'1': 'ACTION_TYPE_OPEN_APP', '2': 3},
  ],
};

/// Descriptor for `ActionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List actionTypeDescriptor = $convert.base64Decode(
    'CgpBY3Rpb25UeXBlEhsKF0FDVElPTl9UWVBFX1VOU1BFQ0lGSUVEEAASFwoTQUNUSU9OX1RZUE'
    'VfQ09ORklSTRABEhcKE0FDVElPTl9UWVBFX0RJU01JU1MQAhIYChRBQ1RJT05fVFlQRV9PUEVO'
    'X0FQUBAD');

@$core.Deprecated('Use agentSubmitRequestDescriptor instead')
const AgentSubmitRequest$json = {
  '1': 'AgentSubmitRequest',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'contexts', '3': 2, '4': 3, '5': 9, '10': 'contexts'},
    {'1': 'session_id', '3': 3, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `AgentSubmitRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentSubmitRequestDescriptor = $convert.base64Decode(
    'ChJBZ2VudFN1Ym1pdFJlcXVlc3QSEgoEdGV4dBgBIAEoCVIEdGV4dBIaCghjb250ZXh0cxgCIA'
    'MoCVIIY29udGV4dHMSHQoKc2Vzc2lvbl9pZBgDIAEoCVIJc2Vzc2lvbklk');

@$core.Deprecated('Use agentSubmitResponseDescriptor instead')
const AgentSubmitResponse$json = {
  '1': 'AgentSubmitResponse',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'actions', '3': 2, '4': 3, '5': 11, '6': '.ivi.agent.ActionSummary', '10': 'actions'},
    {'1': 'session_id', '3': 3, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `AgentSubmitResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentSubmitResponseDescriptor = $convert.base64Decode(
    'ChNBZ2VudFN1Ym1pdFJlc3BvbnNlEhIKBHRleHQYASABKAlSBHRleHQSMgoHYWN0aW9ucxgCIA'
    'MoCzIYLml2aS5hZ2VudC5BY3Rpb25TdW1tYXJ5UgdhY3Rpb25zEh0KCnNlc3Npb25faWQYAyAB'
    'KAlSCXNlc3Npb25JZA==');

@$core.Deprecated('Use actionSummaryDescriptor instead')
const ActionSummary$json = {
  '1': 'ActionSummary',
  '2': [
    {'1': 'tool', '3': 1, '4': 1, '5': 9, '10': 'tool'},
    {'1': 'summary', '3': 2, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'success', '3': 3, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `ActionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List actionSummaryDescriptor = $convert.base64Decode(
    'Cg1BY3Rpb25TdW1tYXJ5EhIKBHRvb2wYASABKAlSBHRvb2wSGAoHc3VtbWFyeRgCIAEoCVIHc3'
    'VtbWFyeRIYCgdzdWNjZXNzGAMgASgIUgdzdWNjZXNz');

@$core.Deprecated('Use subscribeRequestDescriptor instead')
const SubscribeRequest$json = {
  '1': 'SubscribeRequest',
  '2': [
    {'1': 'categories', '3': 1, '4': 3, '5': 9, '10': 'categories'},
  ],
};

/// Descriptor for `SubscribeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeRequestDescriptor = $convert.base64Decode(
    'ChBTdWJzY3JpYmVSZXF1ZXN0Eh4KCmNhdGVnb3JpZXMYASADKAlSCmNhdGVnb3JpZXM=');

@$core.Deprecated('Use proactiveCardDescriptor instead')
const ProactiveCard$json = {
  '1': 'ProactiveCard',
  '2': [
    {'1': 'card_id', '3': 1, '4': 1, '5': 9, '10': 'cardId'},
    {'1': 'category', '3': 2, '4': 1, '5': 9, '10': 'category'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'body', '3': 4, '4': 1, '5': 9, '10': 'body'},
    {'1': 'actions', '3': 5, '4': 3, '5': 11, '6': '.ivi.agent.CardAction', '10': 'actions'},
  ],
};

/// Descriptor for `ProactiveCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proactiveCardDescriptor = $convert.base64Decode(
    'Cg1Qcm9hY3RpdmVDYXJkEhcKB2NhcmRfaWQYASABKAlSBmNhcmRJZBIaCghjYXRlZ29yeRgCIA'
    'EoCVIIY2F0ZWdvcnkSFAoFdGl0bGUYAyABKAlSBXRpdGxlEhIKBGJvZHkYBCABKAlSBGJvZHkS'
    'LwoHYWN0aW9ucxgFIAMoCzIVLml2aS5hZ2VudC5DYXJkQWN0aW9uUgdhY3Rpb25z');

@$core.Deprecated('Use cardActionDescriptor instead')
const CardAction$json = {
  '1': 'CardAction',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'action_type', '3': 2, '4': 1, '5': 14, '6': '.ivi.agent.ActionType', '10': 'actionType'},
  ],
};

/// Descriptor for `CardAction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cardActionDescriptor = $convert.base64Decode(
    'CgpDYXJkQWN0aW9uEhQKBWxhYmVsGAEgASgJUgVsYWJlbBI2CgthY3Rpb25fdHlwZRgCIAEoDj'
    'IVLml2aS5hZ2VudC5BY3Rpb25UeXBlUgphY3Rpb25UeXBl');

