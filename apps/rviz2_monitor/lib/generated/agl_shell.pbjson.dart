//
//  Generated code. Do not modify.
//  source: agl_shell.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use activateRequestDescriptor instead')
const ActivateRequest$json = {
  '1': 'ActivateRequest',
  '2': [
    {'1': 'app_id', '3': 1, '4': 1, '5': 9, '10': 'appId'},
    {'1': 'output_name', '3': 2, '4': 1, '5': 9, '10': 'outputName'},
  ],
};

/// Descriptor for `ActivateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activateRequestDescriptor = $convert.base64Decode(
    'Cg9BY3RpdmF0ZVJlcXVlc3QSFQoGYXBwX2lkGAEgASgJUgVhcHBJZBIfCgtvdXRwdXRfbmFtZR'
    'gCIAEoCVIKb3V0cHV0TmFtZQ==');

@$core.Deprecated('Use activateResponseDescriptor instead')
const ActivateResponse$json = {
  '1': 'ActivateResponse',
};

/// Descriptor for `ActivateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List activateResponseDescriptor = $convert.base64Decode(
    'ChBBY3RpdmF0ZVJlc3BvbnNl');

