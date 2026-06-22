//
//  Generated code. Do not modify.
//  source: speech.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use synthesizeRequestDescriptor instead')
const SynthesizeRequest$json = {
  '1': 'SynthesizeRequest',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'locale', '3': 2, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'pipeline_id', '3': 3, '4': 1, '5': 9, '10': 'pipelineId'},
    {'1': 'speaker_id', '3': 4, '4': 1, '5': 5, '10': 'speakerId'},
  ],
};

/// Descriptor for `SynthesizeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List synthesizeRequestDescriptor = $convert.base64Decode(
    'ChFTeW50aGVzaXplUmVxdWVzdBISCgR0ZXh0GAEgASgJUgR0ZXh0EhYKBmxvY2FsZRgCIAEoCV'
    'IGbG9jYWxlEh8KC3BpcGVsaW5lX2lkGAMgASgJUgpwaXBlbGluZUlkEh0KCnNwZWFrZXJfaWQY'
    'BCABKAVSCXNwZWFrZXJJZA==');

@$core.Deprecated('Use synthesizeResponseDescriptor instead')
const SynthesizeResponse$json = {
  '1': 'SynthesizeResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'audio', '3': 2, '4': 1, '5': 12, '10': 'audio'},
    {'1': 'sample_rate_hz', '3': 3, '4': 1, '5': 13, '10': 'sampleRateHz'},
    {'1': 'channels', '3': 4, '4': 1, '5': 13, '10': 'channels'},
    {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `SynthesizeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List synthesizeResponseDescriptor = $convert.base64Decode(
    'ChJTeW50aGVzaXplUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIUCgVhdWRpbx'
    'gCIAEoDFIFYXVkaW8SJAoOc2FtcGxlX3JhdGVfaHoYAyABKA1SDHNhbXBsZVJhdGVIehIaCghj'
    'aGFubmVscxgEIAEoDVIIY2hhbm5lbHMSIwoNZXJyb3JfbWVzc2FnZRgFIAEoCVIMZXJyb3JNZX'
    'NzYWdl');

@$core.Deprecated('Use listSpeechPipelinesRequestDescriptor instead')
const ListSpeechPipelinesRequest$json = {
  '1': 'ListSpeechPipelinesRequest',
};

/// Descriptor for `ListSpeechPipelinesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSpeechPipelinesRequestDescriptor = $convert.base64Decode(
    'ChpMaXN0U3BlZWNoUGlwZWxpbmVzUmVxdWVzdA==');

@$core.Deprecated('Use listSpeechPipelinesResponseDescriptor instead')
const ListSpeechPipelinesResponse$json = {
  '1': 'ListSpeechPipelinesResponse',
  '2': [
    {'1': 'pipelines', '3': 1, '4': 3, '5': 11, '6': '.oais.common.v1.PipelineInfo', '10': 'pipelines'},
  ],
};

/// Descriptor for `ListSpeechPipelinesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSpeechPipelinesResponseDescriptor = $convert.base64Decode(
    'ChtMaXN0U3BlZWNoUGlwZWxpbmVzUmVzcG9uc2USOgoJcGlwZWxpbmVzGAEgAygLMhwub2Fpcy'
    '5jb21tb24udjEuUGlwZWxpbmVJbmZvUglwaXBlbGluZXM=');

@$core.Deprecated('Use transcribeRequestDescriptor instead')
const TranscribeRequest$json = {
  '1': 'TranscribeRequest',
  '2': [
    {'1': 'pipeline_id', '3': 1, '4': 1, '5': 9, '10': 'pipelineId'},
    {'1': 'audio', '3': 2, '4': 1, '5': 12, '10': 'audio'},
    {'1': 'format', '3': 3, '4': 1, '5': 11, '6': '.oais.common.v1.AudioFormat', '10': 'format'},
    {'1': 'locale', '3': 4, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'enable_postprocess', '3': 5, '4': 1, '5': 8, '10': 'enablePostprocess'},
  ],
};

/// Descriptor for `TranscribeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transcribeRequestDescriptor = $convert.base64Decode(
    'ChFUcmFuc2NyaWJlUmVxdWVzdBIfCgtwaXBlbGluZV9pZBgBIAEoCVIKcGlwZWxpbmVJZBIUCg'
    'VhdWRpbxgCIAEoDFIFYXVkaW8SMwoGZm9ybWF0GAMgASgLMhsub2Fpcy5jb21tb24udjEuQXVk'
    'aW9Gb3JtYXRSBmZvcm1hdBIWCgZsb2NhbGUYBCABKAlSBmxvY2FsZRItChJlbmFibGVfcG9zdH'
    'Byb2Nlc3MYBSABKAhSEWVuYWJsZVBvc3Rwcm9jZXNz');

@$core.Deprecated('Use transcribeResponseDescriptor instead')
const TranscribeResponse$json = {
  '1': 'TranscribeResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'transcript', '3': 2, '4': 1, '5': 9, '10': 'transcript'},
    {'1': 'normalized_text', '3': 3, '4': 1, '5': 9, '10': 'normalizedText'},
    {'1': 'error_message', '3': 4, '4': 1, '5': 9, '10': 'errorMessage'},
    {'1': 'pipeline_id', '3': 5, '4': 1, '5': 9, '10': 'pipelineId'},
    {'1': 'metrics', '3': 6, '4': 1, '5': 11, '6': '.oais.common.v1.MetricSet', '10': 'metrics'},
    {'1': 'metadata', '3': 7, '4': 3, '5': 11, '6': '.oais.speech.v1.TranscribeResponse.MetadataEntry', '10': 'metadata'},
  ],
  '3': [TranscribeResponse_MetadataEntry$json],
};

@$core.Deprecated('Use transcribeResponseDescriptor instead')
const TranscribeResponse_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TranscribeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transcribeResponseDescriptor = $convert.base64Decode(
    'ChJUcmFuc2NyaWJlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIeCgp0cmFuc2'
    'NyaXB0GAIgASgJUgp0cmFuc2NyaXB0EicKD25vcm1hbGl6ZWRfdGV4dBgDIAEoCVIObm9ybWFs'
    'aXplZFRleHQSIwoNZXJyb3JfbWVzc2FnZRgEIAEoCVIMZXJyb3JNZXNzYWdlEh8KC3BpcGVsaW'
    '5lX2lkGAUgASgJUgpwaXBlbGluZUlkEjMKB21ldHJpY3MYBiABKAsyGS5vYWlzLmNvbW1vbi52'
    'MS5NZXRyaWNTZXRSB21ldHJpY3MSTAoIbWV0YWRhdGEYByADKAsyMC5vYWlzLnNwZWVjaC52MS'
    '5UcmFuc2NyaWJlUmVzcG9uc2UuTWV0YWRhdGFFbnRyeVIIbWV0YWRhdGEaOwoNTWV0YWRhdGFF'
    'bnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use transcribeEventDescriptor instead')
const TranscribeEvent$json = {
  '1': 'TranscribeEvent',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'pipeline_id', '3': 2, '4': 1, '5': 9, '10': 'pipelineId'},
    {'1': 'success', '3': 3, '4': 1, '5': 8, '10': 'success'},
    {'1': 'partial', '3': 4, '4': 1, '5': 9, '10': 'partial'},
    {'1': 'final_text', '3': 5, '4': 1, '5': 9, '10': 'finalText'},
    {'1': 'is_final', '3': 6, '4': 1, '5': 8, '10': 'isFinal'},
    {'1': 'error_message', '3': 7, '4': 1, '5': 9, '10': 'errorMessage'},
    {'1': 'metrics', '3': 8, '4': 1, '5': 11, '6': '.oais.common.v1.MetricSet', '10': 'metrics'},
  ],
};

/// Descriptor for `TranscribeEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transcribeEventDescriptor = $convert.base64Decode(
    'Cg9UcmFuc2NyaWJlRXZlbnQSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEh8KC3BpcG'
    'VsaW5lX2lkGAIgASgJUgpwaXBlbGluZUlkEhgKB3N1Y2Nlc3MYAyABKAhSB3N1Y2Nlc3MSGAoH'
    'cGFydGlhbBgEIAEoCVIHcGFydGlhbBIdCgpmaW5hbF90ZXh0GAUgASgJUglmaW5hbFRleHQSGQ'
    'oIaXNfZmluYWwYBiABKAhSB2lzRmluYWwSIwoNZXJyb3JfbWVzc2FnZRgHIAEoCVIMZXJyb3JN'
    'ZXNzYWdlEjMKB21ldHJpY3MYCCABKAsyGS5vYWlzLmNvbW1vbi52MS5NZXRyaWNTZXRSB21ldH'
    'JpY3M=');

