//
//  Generated code. Do not modify.
//  source: VISSv3.0.proto
//
// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use responseStatusDescriptor instead')
const ResponseStatus$json = {
  '1': 'ResponseStatus',
  '2': [
    {'1': 'SUCCESS', '2': 0},
    {'1': 'ERROR', '2': 1},
  ],
};

/// Descriptor for `ResponseStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List responseStatusDescriptor = $convert
    .base64Decode('Cg5SZXNwb25zZVN0YXR1cxILCgdTVUNDRVNTEAASCQoFRVJST1IQAQ==');

@$core.Deprecated('Use subscribeResponseTypeDescriptor instead')
const SubscribeResponseType$json = {
  '1': 'SubscribeResponseType',
  '2': [
    {'1': 'RESPONSE', '2': 0},
    {'1': 'EVENT', '2': 1},
  ],
};

/// Descriptor for `SubscribeResponseType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List subscribeResponseTypeDescriptor =
    $convert.base64Decode(
        'ChVTdWJzY3JpYmVSZXNwb25zZVR5cGUSDAoIUkVTUE9OU0UQABIJCgVFVkVOVBAB');

@$core.Deprecated('Use errorResponseMessageDescriptor instead')
const ErrorResponseMessage$json = {
  '1': 'ErrorResponseMessage',
  '2': [
    {'1': 'Number', '3': 1, '4': 1, '5': 9, '10': 'Number'},
    {'1': 'Reason', '3': 2, '4': 1, '5': 9, '10': 'Reason'},
    {'1': 'Description', '3': 3, '4': 1, '5': 9, '10': 'Description'},
  ],
};

/// Descriptor for `ErrorResponseMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorResponseMessageDescriptor = $convert.base64Decode(
    'ChRFcnJvclJlc3BvbnNlTWVzc2FnZRIWCgZOdW1iZXIYASABKAlSBk51bWJlchIWCgZSZWFzb2'
    '4YAiABKAlSBlJlYXNvbhIgCgtEZXNjcmlwdGlvbhgDIAEoCVILRGVzY3JpcHRpb24=');

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions$json = {
  '1': 'FilterExpressions',
  '2': [
    {
      '1': 'FilterExp',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.grpcProtobufMessages.FilterExpressions.FilterExpression',
      '10': 'FilterExp'
    },
  ],
  '3': [FilterExpressions_FilterExpression$json],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression$json = {
  '1': 'FilterExpression',
  '2': [
    {
      '1': 'Variant',
      '3': 1,
      '4': 1,
      '5': 14,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterVariant',
      '10': 'Variant'
    },
    {
      '1': 'Value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue',
      '10': 'Value'
    },
  ],
  '3': [FilterExpressions_FilterExpression_FilterValue$json],
  '4': [FilterExpressions_FilterExpression_FilterVariant$json],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue$json = {
  '1': 'FilterValue',
  '2': [
    {
      '1': 'ValuePaths',
      '3': 1,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.PathsValue',
      '9': 0,
      '10': 'ValuePaths',
      '17': true
    },
    {
      '1': 'ValueTimebased',
      '3': 2,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.TimebasedValue',
      '9': 1,
      '10': 'ValueTimebased',
      '17': true
    },
    {
      '1': 'ValueRange',
      '3': 3,
      '4': 3,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.RangeValue',
      '10': 'ValueRange'
    },
    {
      '1': 'ValueChange',
      '3': 4,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.ChangeValue',
      '9': 2,
      '10': 'ValueChange',
      '17': true
    },
    {
      '1': 'ValueCurvelog',
      '3': 5,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.CurvelogValue',
      '9': 3,
      '10': 'ValueCurvelog',
      '17': true
    },
    {
      '1': 'ValueHistory',
      '3': 6,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.HistoryValue',
      '9': 4,
      '10': 'ValueHistory',
      '17': true
    },
    {
      '1': 'ValueMetadata',
      '3': 7,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.FilterExpressions.FilterExpression.FilterValue.MetadataValue',
      '9': 5,
      '10': 'ValueMetadata',
      '17': true
    },
  ],
  '3': [
    FilterExpressions_FilterExpression_FilterValue_PathsValue$json,
    FilterExpressions_FilterExpression_FilterValue_TimebasedValue$json,
    FilterExpressions_FilterExpression_FilterValue_RangeValue$json,
    FilterExpressions_FilterExpression_FilterValue_ChangeValue$json,
    FilterExpressions_FilterExpression_FilterValue_CurvelogValue$json,
    FilterExpressions_FilterExpression_FilterValue_HistoryValue$json,
    FilterExpressions_FilterExpression_FilterValue_MetadataValue$json
  ],
  '8': [
    {'1': '_ValuePaths'},
    {'1': '_ValueTimebased'},
    {'1': '_ValueChange'},
    {'1': '_ValueCurvelog'},
    {'1': '_ValueHistory'},
    {'1': '_ValueMetadata'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_PathsValue$json = {
  '1': 'PathsValue',
  '2': [
    {'1': 'RelativePath', '3': 1, '4': 3, '5': 9, '10': 'RelativePath'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_TimebasedValue$json = {
  '1': 'TimebasedValue',
  '2': [
    {'1': 'Period', '3': 1, '4': 1, '5': 9, '10': 'Period'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_RangeValue$json = {
  '1': 'RangeValue',
  '2': [
    {'1': 'LogicOperator', '3': 1, '4': 1, '5': 9, '10': 'LogicOperator'},
    {'1': 'Boundary', '3': 2, '4': 1, '5': 9, '10': 'Boundary'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_ChangeValue$json = {
  '1': 'ChangeValue',
  '2': [
    {'1': 'LogicOperator', '3': 1, '4': 1, '5': 9, '10': 'LogicOperator'},
    {'1': 'Diff', '3': 2, '4': 1, '5': 9, '10': 'Diff'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_CurvelogValue$json = {
  '1': 'CurvelogValue',
  '2': [
    {'1': 'MaxErr', '3': 1, '4': 1, '5': 9, '10': 'MaxErr'},
    {'1': 'BufSize', '3': 2, '4': 1, '5': 9, '10': 'BufSize'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_HistoryValue$json = {
  '1': 'HistoryValue',
  '2': [
    {'1': 'TimePeriod', '3': 1, '4': 1, '5': 9, '10': 'TimePeriod'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterValue_MetadataValue$json = {
  '1': 'MetadataValue',
  '2': [
    {'1': 'Tree', '3': 1, '4': 1, '5': 9, '10': 'Tree'},
  ],
};

@$core.Deprecated('Use filterExpressionsDescriptor instead')
const FilterExpressions_FilterExpression_FilterVariant$json = {
  '1': 'FilterVariant',
  '2': [
    {'1': 'PATHS', '2': 0},
    {'1': 'TIMEBASED', '2': 1},
    {'1': 'RANGE', '2': 2},
    {'1': 'CHANGE', '2': 3},
    {'1': 'CURVELOG', '2': 4},
    {'1': 'HISTORY', '2': 5},
    {'1': 'METADATA', '2': 6},
  ],
};

/// Descriptor for `FilterExpressions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filterExpressionsDescriptor = $convert.base64Decode(
    'ChFGaWx0ZXJFeHByZXNzaW9ucxJWCglGaWx0ZXJFeHAYASADKAsyOC5ncnBjUHJvdG9idWZNZX'
    'NzYWdlcy5GaWx0ZXJFeHByZXNzaW9ucy5GaWx0ZXJFeHByZXNzaW9uUglGaWx0ZXJFeHAanA0K'
    'EEZpbHRlckV4cHJlc3Npb24SYAoHVmFyaWFudBgBIAEoDjJGLmdycGNQcm90b2J1Zk1lc3NhZ2'
    'VzLkZpbHRlckV4cHJlc3Npb25zLkZpbHRlckV4cHJlc3Npb24uRmlsdGVyVmFyaWFudFIHVmFy'
    'aWFudBJaCgVWYWx1ZRgCIAEoCzJELmdycGNQcm90b2J1Zk1lc3NhZ2VzLkZpbHRlckV4cHJlc3'
    'Npb25zLkZpbHRlckV4cHJlc3Npb24uRmlsdGVyVmFsdWVSBVZhbHVlGt4KCgtGaWx0ZXJWYWx1'
    'ZRJ0CgpWYWx1ZVBhdGhzGAEgASgLMk8uZ3JwY1Byb3RvYnVmTWVzc2FnZXMuRmlsdGVyRXhwcm'
    'Vzc2lvbnMuRmlsdGVyRXhwcmVzc2lvbi5GaWx0ZXJWYWx1ZS5QYXRoc1ZhbHVlSABSClZhbHVl'
    'UGF0aHOIAQESgAEKDlZhbHVlVGltZWJhc2VkGAIgASgLMlMuZ3JwY1Byb3RvYnVmTWVzc2FnZX'
    'MuRmlsdGVyRXhwcmVzc2lvbnMuRmlsdGVyRXhwcmVzc2lvbi5GaWx0ZXJWYWx1ZS5UaW1lYmFz'
    'ZWRWYWx1ZUgBUg5WYWx1ZVRpbWViYXNlZIgBARJvCgpWYWx1ZVJhbmdlGAMgAygLMk8uZ3JwY1'
    'Byb3RvYnVmTWVzc2FnZXMuRmlsdGVyRXhwcmVzc2lvbnMuRmlsdGVyRXhwcmVzc2lvbi5GaWx0'
    'ZXJWYWx1ZS5SYW5nZVZhbHVlUgpWYWx1ZVJhbmdlEncKC1ZhbHVlQ2hhbmdlGAQgASgLMlAuZ3'
    'JwY1Byb3RvYnVmTWVzc2FnZXMuRmlsdGVyRXhwcmVzc2lvbnMuRmlsdGVyRXhwcmVzc2lvbi5G'
    'aWx0ZXJWYWx1ZS5DaGFuZ2VWYWx1ZUgCUgtWYWx1ZUNoYW5nZYgBARJ9Cg1WYWx1ZUN1cnZlbG'
    '9nGAUgASgLMlIuZ3JwY1Byb3RvYnVmTWVzc2FnZXMuRmlsdGVyRXhwcmVzc2lvbnMuRmlsdGVy'
    'RXhwcmVzc2lvbi5GaWx0ZXJWYWx1ZS5DdXJ2ZWxvZ1ZhbHVlSANSDVZhbHVlQ3VydmVsb2eIAQ'
    'ESegoMVmFsdWVIaXN0b3J5GAYgASgLMlEuZ3JwY1Byb3RvYnVmTWVzc2FnZXMuRmlsdGVyRXhw'
    'cmVzc2lvbnMuRmlsdGVyRXhwcmVzc2lvbi5GaWx0ZXJWYWx1ZS5IaXN0b3J5VmFsdWVIBFIMVm'
    'FsdWVIaXN0b3J5iAEBEn0KDVZhbHVlTWV0YWRhdGEYByABKAsyUi5ncnBjUHJvdG9idWZNZXNz'
    'YWdlcy5GaWx0ZXJFeHByZXNzaW9ucy5GaWx0ZXJFeHByZXNzaW9uLkZpbHRlclZhbHVlLk1ldG'
    'FkYXRhVmFsdWVIBVINVmFsdWVNZXRhZGF0YYgBARowCgpQYXRoc1ZhbHVlEiIKDFJlbGF0aXZl'
    'UGF0aBgBIAMoCVIMUmVsYXRpdmVQYXRoGigKDlRpbWViYXNlZFZhbHVlEhYKBlBlcmlvZBgBIA'
    'EoCVIGUGVyaW9kGk4KClJhbmdlVmFsdWUSJAoNTG9naWNPcGVyYXRvchgBIAEoCVINTG9naWNP'
    'cGVyYXRvchIaCghCb3VuZGFyeRgCIAEoCVIIQm91bmRhcnkaRwoLQ2hhbmdlVmFsdWUSJAoNTG'
    '9naWNPcGVyYXRvchgBIAEoCVINTG9naWNPcGVyYXRvchISCgREaWZmGAIgASgJUgREaWZmGkEK'
    'DUN1cnZlbG9nVmFsdWUSFgoGTWF4RXJyGAEgASgJUgZNYXhFcnISGAoHQnVmU2l6ZRgCIAEoCV'
    'IHQnVmU2l6ZRouCgxIaXN0b3J5VmFsdWUSHgoKVGltZVBlcmlvZBgBIAEoCVIKVGltZVBlcmlv'
    'ZBojCg1NZXRhZGF0YVZhbHVlEhIKBFRyZWUYASABKAlSBFRyZWVCDQoLX1ZhbHVlUGF0aHNCEQ'
    'oPX1ZhbHVlVGltZWJhc2VkQg4KDF9WYWx1ZUNoYW5nZUIQCg5fVmFsdWVDdXJ2ZWxvZ0IPCg1f'
    'VmFsdWVIaXN0b3J5QhAKDl9WYWx1ZU1ldGFkYXRhImkKDUZpbHRlclZhcmlhbnQSCQoFUEFUSF'
    'MQABINCglUSU1FQkFTRUQQARIJCgVSQU5HRRACEgoKBkNIQU5HRRADEgwKCENVUlZFTE9HEAQS'
    'CwoHSElTVE9SWRAFEgwKCE1FVEFEQVRBEAY=');

@$core.Deprecated('Use dataPackagesDescriptor instead')
const DataPackages$json = {
  '1': 'DataPackages',
  '2': [
    {
      '1': 'Data',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.grpcProtobufMessages.DataPackages.DataPackage',
      '10': 'Data'
    },
  ],
  '3': [DataPackages_DataPackage$json],
};

@$core.Deprecated('Use dataPackagesDescriptor instead')
const DataPackages_DataPackage$json = {
  '1': 'DataPackage',
  '2': [
    {'1': 'Path', '3': 1, '4': 1, '5': 9, '10': 'Path'},
    {
      '1': 'Dp',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.grpcProtobufMessages.DataPackages.DataPackage.DataPoint',
      '10': 'Dp'
    },
  ],
  '3': [DataPackages_DataPackage_DataPoint$json],
};

@$core.Deprecated('Use dataPackagesDescriptor instead')
const DataPackages_DataPackage_DataPoint$json = {
  '1': 'DataPoint',
  '2': [
    {'1': 'Value', '3': 1, '4': 1, '5': 9, '10': 'Value'},
    {'1': 'Ts', '3': 2, '4': 1, '5': 9, '10': 'Ts'},
  ],
};

/// Descriptor for `DataPackages`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dataPackagesDescriptor = $convert.base64Decode(
    'CgxEYXRhUGFja2FnZXMSQgoERGF0YRgBIAMoCzIuLmdycGNQcm90b2J1Zk1lc3NhZ2VzLkRhdG'
    'FQYWNrYWdlcy5EYXRhUGFja2FnZVIERGF0YRqeAQoLRGF0YVBhY2thZ2USEgoEUGF0aBgBIAEo'
    'CVIEUGF0aBJICgJEcBgCIAMoCzI4LmdycGNQcm90b2J1Zk1lc3NhZ2VzLkRhdGFQYWNrYWdlcy'
    '5EYXRhUGFja2FnZS5EYXRhUG9pbnRSAkRwGjEKCURhdGFQb2ludBIUCgVWYWx1ZRgBIAEoCVIF'
    'VmFsdWUSDgoCVHMYAiABKAlSAlRz');

@$core.Deprecated('Use getRequestMessageDescriptor instead')
const GetRequestMessage$json = {
  '1': 'GetRequestMessage',
  '2': [
    {'1': 'Path', '3': 1, '4': 1, '5': 9, '10': 'Path'},
    {
      '1': 'Filter',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.FilterExpressions',
      '9': 0,
      '10': 'Filter',
      '17': true
    },
    {
      '1': 'Authorization',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'Authorization',
      '17': true
    },
    {
      '1': 'DataCompression',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'DataCompression',
      '17': true
    },
    {
      '1': 'RequestId',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'RequestId',
      '17': true
    },
  ],
  '8': [
    {'1': '_Filter'},
    {'1': '_Authorization'},
    {'1': '_DataCompression'},
    {'1': '_RequestId'},
  ],
};

/// Descriptor for `GetRequestMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRequestMessageDescriptor = $convert.base64Decode(
    'ChFHZXRSZXF1ZXN0TWVzc2FnZRISCgRQYXRoGAEgASgJUgRQYXRoEkQKBkZpbHRlchgCIAEoCz'
    'InLmdycGNQcm90b2J1Zk1lc3NhZ2VzLkZpbHRlckV4cHJlc3Npb25zSABSBkZpbHRlcogBARIp'
    'Cg1BdXRob3JpemF0aW9uGAMgASgJSAFSDUF1dGhvcml6YXRpb26IAQESLQoPRGF0YUNvbXByZX'
    'NzaW9uGAQgASgJSAJSD0RhdGFDb21wcmVzc2lvbogBARIhCglSZXF1ZXN0SWQYBSABKAlIA1IJ'
    'UmVxdWVzdElkiAEBQgkKB19GaWx0ZXJCEAoOX0F1dGhvcml6YXRpb25CEgoQX0RhdGFDb21wcm'
    'Vzc2lvbkIMCgpfUmVxdWVzdElk');

@$core.Deprecated('Use getResponseMessageDescriptor instead')
const GetResponseMessage$json = {
  '1': 'GetResponseMessage',
  '2': [
    {
      '1': 'Status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.grpcProtobufMessages.ResponseStatus',
      '10': 'Status'
    },
    {
      '1': 'SuccessResponse',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.GetResponseMessage.SuccessResponseMessage',
      '9': 0,
      '10': 'SuccessResponse',
      '17': true
    },
    {
      '1': 'ErrorResponse',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.ErrorResponseMessage',
      '9': 1,
      '10': 'ErrorResponse',
      '17': true
    },
    {
      '1': 'RequestId',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'RequestId',
      '17': true
    },
    {'1': 'Ts', '3': 5, '4': 1, '5': 9, '10': 'Ts'},
    {
      '1': 'Authorization',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'Authorization',
      '17': true
    },
  ],
  '3': [GetResponseMessage_SuccessResponseMessage$json],
  '8': [
    {'1': '_SuccessResponse'},
    {'1': '_ErrorResponse'},
    {'1': '_RequestId'},
    {'1': '_Authorization'},
  ],
};

@$core.Deprecated('Use getResponseMessageDescriptor instead')
const GetResponseMessage_SuccessResponseMessage$json = {
  '1': 'SuccessResponseMessage',
  '2': [
    {
      '1': 'DataPack',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.DataPackages',
      '9': 0,
      '10': 'DataPack',
      '17': true
    },
    {
      '1': 'Metadata',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'Metadata',
      '17': true
    },
  ],
  '8': [
    {'1': '_DataPack'},
    {'1': '_Metadata'},
  ],
};

/// Descriptor for `GetResponseMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getResponseMessageDescriptor = $convert.base64Decode(
    'ChJHZXRSZXNwb25zZU1lc3NhZ2USPAoGU3RhdHVzGAEgASgOMiQuZ3JwY1Byb3RvYnVmTWVzc2'
    'FnZXMuUmVzcG9uc2VTdGF0dXNSBlN0YXR1cxJuCg9TdWNjZXNzUmVzcG9uc2UYAiABKAsyPy5n'
    'cnBjUHJvdG9idWZNZXNzYWdlcy5HZXRSZXNwb25zZU1lc3NhZ2UuU3VjY2Vzc1Jlc3BvbnNlTW'
    'Vzc2FnZUgAUg9TdWNjZXNzUmVzcG9uc2WIAQESVQoNRXJyb3JSZXNwb25zZRgDIAEoCzIqLmdy'
    'cGNQcm90b2J1Zk1lc3NhZ2VzLkVycm9yUmVzcG9uc2VNZXNzYWdlSAFSDUVycm9yUmVzcG9uc2'
    'WIAQESIQoJUmVxdWVzdElkGAQgASgJSAJSCVJlcXVlc3RJZIgBARIOCgJUcxgFIAEoCVICVHMS'
    'KQoNQXV0aG9yaXphdGlvbhgGIAEoCUgDUg1BdXRob3JpemF0aW9uiAEBGpgBChZTdWNjZXNzUm'
    'VzcG9uc2VNZXNzYWdlEkMKCERhdGFQYWNrGAEgASgLMiIuZ3JwY1Byb3RvYnVmTWVzc2FnZXMu'
    'RGF0YVBhY2thZ2VzSABSCERhdGFQYWNriAEBEh8KCE1ldGFkYXRhGAIgASgJSAFSCE1ldGFkYX'
    'RhiAEBQgsKCV9EYXRhUGFja0ILCglfTWV0YWRhdGFCEgoQX1N1Y2Nlc3NSZXNwb25zZUIQCg5f'
    'RXJyb3JSZXNwb25zZUIMCgpfUmVxdWVzdElkQhAKDl9BdXRob3JpemF0aW9u');

@$core.Deprecated('Use setRequestMessageDescriptor instead')
const SetRequestMessage$json = {
  '1': 'SetRequestMessage',
  '2': [
    {'1': 'Path', '3': 1, '4': 1, '5': 9, '10': 'Path'},
    {'1': 'Value', '3': 2, '4': 1, '5': 9, '10': 'Value'},
    {
      '1': 'Authorization',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'Authorization',
      '17': true
    },
    {
      '1': 'RequestId',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'RequestId',
      '17': true
    },
  ],
  '8': [
    {'1': '_Authorization'},
    {'1': '_RequestId'},
  ],
};

/// Descriptor for `SetRequestMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRequestMessageDescriptor = $convert.base64Decode(
    'ChFTZXRSZXF1ZXN0TWVzc2FnZRISCgRQYXRoGAEgASgJUgRQYXRoEhQKBVZhbHVlGAIgASgJUg'
    'VWYWx1ZRIpCg1BdXRob3JpemF0aW9uGAMgASgJSABSDUF1dGhvcml6YXRpb26IAQESIQoJUmVx'
    'dWVzdElkGAQgASgJSAFSCVJlcXVlc3RJZIgBAUIQCg5fQXV0aG9yaXphdGlvbkIMCgpfUmVxdW'
    'VzdElk');

@$core.Deprecated('Use setResponseMessageDescriptor instead')
const SetResponseMessage$json = {
  '1': 'SetResponseMessage',
  '2': [
    {
      '1': 'Status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.grpcProtobufMessages.ResponseStatus',
      '10': 'Status'
    },
    {
      '1': 'ErrorResponse',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.ErrorResponseMessage',
      '9': 0,
      '10': 'ErrorResponse',
      '17': true
    },
    {
      '1': 'RequestId',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'RequestId',
      '17': true
    },
    {'1': 'Ts', '3': 4, '4': 1, '5': 9, '10': 'Ts'},
    {
      '1': 'Authorization',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'Authorization',
      '17': true
    },
  ],
  '8': [
    {'1': '_ErrorResponse'},
    {'1': '_RequestId'},
    {'1': '_Authorization'},
  ],
};

/// Descriptor for `SetResponseMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setResponseMessageDescriptor = $convert.base64Decode(
    'ChJTZXRSZXNwb25zZU1lc3NhZ2USPAoGU3RhdHVzGAEgASgOMiQuZ3JwY1Byb3RvYnVmTWVzc2'
    'FnZXMuUmVzcG9uc2VTdGF0dXNSBlN0YXR1cxJVCg1FcnJvclJlc3BvbnNlGAIgASgLMiouZ3Jw'
    'Y1Byb3RvYnVmTWVzc2FnZXMuRXJyb3JSZXNwb25zZU1lc3NhZ2VIAFINRXJyb3JSZXNwb25zZY'
    'gBARIhCglSZXF1ZXN0SWQYAyABKAlIAVIJUmVxdWVzdElkiAEBEg4KAlRzGAQgASgJUgJUcxIp'
    'Cg1BdXRob3JpemF0aW9uGAUgASgJSAJSDUF1dGhvcml6YXRpb26IAQFCEAoOX0Vycm9yUmVzcG'
    '9uc2VCDAoKX1JlcXVlc3RJZEIQCg5fQXV0aG9yaXphdGlvbg==');

@$core.Deprecated('Use subscribeRequestMessageDescriptor instead')
const SubscribeRequestMessage$json = {
  '1': 'SubscribeRequestMessage',
  '2': [
    {'1': 'Path', '3': 1, '4': 1, '5': 9, '10': 'Path'},
    {
      '1': 'Filter',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.FilterExpressions',
      '9': 0,
      '10': 'Filter',
      '17': true
    },
    {
      '1': 'Authorization',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'Authorization',
      '17': true
    },
    {
      '1': 'DataCompression',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'DataCompression',
      '17': true
    },
    {'1': 'RequestId', '3': 5, '4': 1, '5': 9, '10': 'RequestId'},
  ],
  '8': [
    {'1': '_Filter'},
    {'1': '_Authorization'},
    {'1': '_DataCompression'},
  ],
};

/// Descriptor for `SubscribeRequestMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeRequestMessageDescriptor = $convert.base64Decode(
    'ChdTdWJzY3JpYmVSZXF1ZXN0TWVzc2FnZRISCgRQYXRoGAEgASgJUgRQYXRoEkQKBkZpbHRlch'
    'gCIAEoCzInLmdycGNQcm90b2J1Zk1lc3NhZ2VzLkZpbHRlckV4cHJlc3Npb25zSABSBkZpbHRl'
    'cogBARIpCg1BdXRob3JpemF0aW9uGAMgASgJSAFSDUF1dGhvcml6YXRpb26IAQESLQoPRGF0YU'
    'NvbXByZXNzaW9uGAQgASgJSAJSD0RhdGFDb21wcmVzc2lvbogBARIcCglSZXF1ZXN0SWQYBSAB'
    'KAlSCVJlcXVlc3RJZEIJCgdfRmlsdGVyQhAKDl9BdXRob3JpemF0aW9uQhIKEF9EYXRhQ29tcH'
    'Jlc3Npb24=');

@$core.Deprecated('Use subscribeStreamMessageDescriptor instead')
const SubscribeStreamMessage$json = {
  '1': 'SubscribeStreamMessage',
  '2': [
    {
      '1': 'MType',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.grpcProtobufMessages.SubscribeResponseType',
      '10': 'MType'
    },
    {
      '1': 'Status',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.grpcProtobufMessages.ResponseStatus',
      '10': 'Status'
    },
    {
      '1': 'Response',
      '3': 3,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.SubscribeStreamMessage.SubscribeResponseMessage',
      '9': 0,
      '10': 'Response',
      '17': true
    },
    {
      '1': 'Event',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.SubscribeStreamMessage.SubscribeEventMessage',
      '9': 1,
      '10': 'Event',
      '17': true
    },
  ],
  '3': [
    SubscribeStreamMessage_SubscribeResponseMessage$json,
    SubscribeStreamMessage_SubscribeEventMessage$json
  ],
  '8': [
    {'1': '_Response'},
    {'1': '_Event'},
  ],
};

@$core.Deprecated('Use subscribeStreamMessageDescriptor instead')
const SubscribeStreamMessage_SubscribeResponseMessage$json = {
  '1': 'SubscribeResponseMessage',
  '2': [
    {
      '1': 'ErrorResponse',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.ErrorResponseMessage',
      '9': 0,
      '10': 'ErrorResponse',
      '17': true
    },
    {
      '1': 'SubscriptionId',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'SubscriptionId',
      '17': true
    },
    {'1': 'RequestId', '3': 3, '4': 1, '5': 9, '10': 'RequestId'},
    {'1': 'Ts', '3': 4, '4': 1, '5': 9, '10': 'Ts'},
    {
      '1': 'Authorization',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'Authorization',
      '17': true
    },
  ],
  '8': [
    {'1': '_ErrorResponse'},
    {'1': '_SubscriptionId'},
    {'1': '_Authorization'},
  ],
};

@$core.Deprecated('Use subscribeStreamMessageDescriptor instead')
const SubscribeStreamMessage_SubscribeEventMessage$json = {
  '1': 'SubscribeEventMessage',
  '2': [
    {'1': 'SubscriptionId', '3': 1, '4': 1, '5': 9, '10': 'SubscriptionId'},
    {
      '1': 'SuccessResponse',
      '3': 2,
      '4': 1,
      '5': 11,
      '6':
          '.grpcProtobufMessages.SubscribeStreamMessage.SubscribeEventMessage.SuccessResponseMessage',
      '9': 0,
      '10': 'SuccessResponse',
      '17': true
    },
    {
      '1': 'ErrorResponse',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.ErrorResponseMessage',
      '9': 1,
      '10': 'ErrorResponse',
      '17': true
    },
    {'1': 'Ts', '3': 4, '4': 1, '5': 9, '10': 'Ts'},
  ],
  '3': [
    SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage$json
  ],
  '8': [
    {'1': '_SuccessResponse'},
    {'1': '_ErrorResponse'},
  ],
};

@$core.Deprecated('Use subscribeStreamMessageDescriptor instead')
const SubscribeStreamMessage_SubscribeEventMessage_SuccessResponseMessage$json =
    {
  '1': 'SuccessResponseMessage',
  '2': [
    {
      '1': 'DataPack',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.DataPackages',
      '10': 'DataPack'
    },
  ],
};

/// Descriptor for `SubscribeStreamMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeStreamMessageDescriptor = $convert.base64Decode(
    'ChZTdWJzY3JpYmVTdHJlYW1NZXNzYWdlEkEKBU1UeXBlGAEgASgOMisuZ3JwY1Byb3RvYnVmTW'
    'Vzc2FnZXMuU3Vic2NyaWJlUmVzcG9uc2VUeXBlUgVNVHlwZRI8CgZTdGF0dXMYAiABKA4yJC5n'
    'cnBjUHJvdG9idWZNZXNzYWdlcy5SZXNwb25zZVN0YXR1c1IGU3RhdHVzEmYKCFJlc3BvbnNlGA'
    'MgASgLMkUuZ3JwY1Byb3RvYnVmTWVzc2FnZXMuU3Vic2NyaWJlU3RyZWFtTWVzc2FnZS5TdWJz'
    'Y3JpYmVSZXNwb25zZU1lc3NhZ2VIAFIIUmVzcG9uc2WIAQESXQoFRXZlbnQYBCABKAsyQi5ncn'
    'BjUHJvdG9idWZNZXNzYWdlcy5TdWJzY3JpYmVTdHJlYW1NZXNzYWdlLlN1YnNjcmliZUV2ZW50'
    'TWVzc2FnZUgBUgVFdmVudIgBARquAgoYU3Vic2NyaWJlUmVzcG9uc2VNZXNzYWdlElUKDUVycm'
    '9yUmVzcG9uc2UYASABKAsyKi5ncnBjUHJvdG9idWZNZXNzYWdlcy5FcnJvclJlc3BvbnNlTWVz'
    'c2FnZUgAUg1FcnJvclJlc3BvbnNliAEBEisKDlN1YnNjcmlwdGlvbklkGAIgASgJSAFSDlN1Yn'
    'NjcmlwdGlvbklkiAEBEhwKCVJlcXVlc3RJZBgDIAEoCVIJUmVxdWVzdElkEg4KAlRzGAQgASgJ'
    'UgJUcxIpCg1BdXRob3JpemF0aW9uGAUgASgJSAJSDUF1dGhvcml6YXRpb26IAQFCEAoOX0Vycm'
    '9yUmVzcG9uc2VCEQoPX1N1YnNjcmlwdGlvbklkQhAKDl9BdXRob3JpemF0aW9uGrEDChVTdWJz'
    'Y3JpYmVFdmVudE1lc3NhZ2USJgoOU3Vic2NyaXB0aW9uSWQYASABKAlSDlN1YnNjcmlwdGlvbk'
    'lkEogBCg9TdWNjZXNzUmVzcG9uc2UYAiABKAsyWS5ncnBjUHJvdG9idWZNZXNzYWdlcy5TdWJz'
    'Y3JpYmVTdHJlYW1NZXNzYWdlLlN1YnNjcmliZUV2ZW50TWVzc2FnZS5TdWNjZXNzUmVzcG9uc2'
    'VNZXNzYWdlSABSD1N1Y2Nlc3NSZXNwb25zZYgBARJVCg1FcnJvclJlc3BvbnNlGAMgASgLMiou'
    'Z3JwY1Byb3RvYnVmTWVzc2FnZXMuRXJyb3JSZXNwb25zZU1lc3NhZ2VIAVINRXJyb3JSZXNwb2'
    '5zZYgBARIOCgJUcxgEIAEoCVICVHMaWAoWU3VjY2Vzc1Jlc3BvbnNlTWVzc2FnZRI+CghEYXRh'
    'UGFjaxgBIAEoCzIiLmdycGNQcm90b2J1Zk1lc3NhZ2VzLkRhdGFQYWNrYWdlc1IIRGF0YVBhY2'
    'tCEgoQX1N1Y2Nlc3NSZXNwb25zZUIQCg5fRXJyb3JSZXNwb25zZUILCglfUmVzcG9uc2VCCAoG'
    'X0V2ZW50');

@$core.Deprecated('Use unsubscribeRequestMessageDescriptor instead')
const UnsubscribeRequestMessage$json = {
  '1': 'UnsubscribeRequestMessage',
  '2': [
    {'1': 'SubscriptionId', '3': 1, '4': 1, '5': 9, '10': 'SubscriptionId'},
    {
      '1': 'RequestId',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'RequestId',
      '17': true
    },
  ],
  '8': [
    {'1': '_RequestId'},
  ],
};

/// Descriptor for `UnsubscribeRequestMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unsubscribeRequestMessageDescriptor = $convert.base64Decode(
    'ChlVbnN1YnNjcmliZVJlcXVlc3RNZXNzYWdlEiYKDlN1YnNjcmlwdGlvbklkGAEgASgJUg5TdW'
    'JzY3JpcHRpb25JZBIhCglSZXF1ZXN0SWQYAiABKAlIAFIJUmVxdWVzdElkiAEBQgwKCl9SZXF1'
    'ZXN0SWQ=');

@$core.Deprecated('Use unsubscribeResponseMessageDescriptor instead')
const UnsubscribeResponseMessage$json = {
  '1': 'UnsubscribeResponseMessage',
  '2': [
    {
      '1': 'Status',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.grpcProtobufMessages.ResponseStatus',
      '10': 'Status'
    },
    {
      '1': 'ErrorResponse',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.grpcProtobufMessages.ErrorResponseMessage',
      '9': 0,
      '10': 'ErrorResponse',
      '17': true
    },
    {
      '1': 'RequestId',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'RequestId',
      '17': true
    },
    {'1': 'Ts', '3': 4, '4': 1, '5': 9, '10': 'Ts'},
  ],
  '8': [
    {'1': '_ErrorResponse'},
    {'1': '_RequestId'},
  ],
};

/// Descriptor for `UnsubscribeResponseMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unsubscribeResponseMessageDescriptor = $convert.base64Decode(
    'ChpVbnN1YnNjcmliZVJlc3BvbnNlTWVzc2FnZRI8CgZTdGF0dXMYASABKA4yJC5ncnBjUHJvdG'
    '9idWZNZXNzYWdlcy5SZXNwb25zZVN0YXR1c1IGU3RhdHVzElUKDUVycm9yUmVzcG9uc2UYAiAB'
    'KAsyKi5ncnBjUHJvdG9idWZNZXNzYWdlcy5FcnJvclJlc3BvbnNlTWVzc2FnZUgAUg1FcnJvcl'
    'Jlc3BvbnNliAEBEiEKCVJlcXVlc3RJZBgDIAEoCUgBUglSZXF1ZXN0SWSIAQESDgoCVHMYBCAB'
    'KAlSAlRzQhAKDl9FcnJvclJlc3BvbnNlQgwKCl9SZXF1ZXN0SWQ=');
