// OTA Manager topic and message type definitions
// Matches actual OtaManager binary (output/x86_64/core/bin/OtaManager):
//   - Topics: /mmf/... (leading slash, no rt/ prefix)
//   - Types:  OtaManager:: namespace

// Response topics (subscribe)
const List<String> otaResponseTopics = [
  '/mmf/otamanager/otaactor_service/GetAppUpdateSettingsResponse',
  '/mmf/otamanager/otaactor_service/SetAppUpdateSettingsResponse',
  '/mmf/otamanager/otaactor_service/GetAppUpdateStateResponse',
  '/mmf/otamanager/otaactor_service/SetAppUpdateResponse',
  '/mmf/otamanager/otaclient_service/NotifyAppUpdateStatus',
];

// Request topics (publish)
const List<String> otaRequestTopics = [
  '/mmf/otamanager/otaactor_service/GetAppUpdateSettings',
  '/mmf/otamanager/otaactor_service/SetAppUpdateSettings',
  '/mmf/otamanager/otaactor_service/GetAppUpdateState',
  '/mmf/otamanager/otaactor_service/SetAppUpdate',
];

// DDS type names for response topics (OtaManager:: namespace)
const List<String> otaDdsResponseTypes = [
  'OtaManager::GetAppUpdateSettingsResponse',
  'OtaManager::SetAppUpdateSettingsResponse',
  'OtaManager::GetAppUpdateStateResponse',
  'OtaManager::SetAppUpdateResponse',
  'OtaManager::NotifyAppUpdateStatus',
];

// DDS type names for request topics
const List<String> otaDdsRequestTypes = [
  'OtaManager::GetAppUpdateSettings',
  'OtaManager::SetAppUpdateSettings',
  'OtaManager::GetAppUpdateState',
  'OtaManager::SetAppUpdate',
];

// ReturnValue enum (matches DDS IDL definition)
enum ReturnValue {
  unknown(0),
  success(1),
  fail(2);

  const ReturnValue(this.value);
  final int value;

  static ReturnValue fromInt(int? val) {
    switch (val) {
      case 1:
        return ReturnValue.success;
      case 2:
        return ReturnValue.fail;
      default:
        return ReturnValue.unknown;
    }
  }
}

// Status text mapping
const Map<int, String> returnValueText = {
  0: 'UNKNOWN',
  1: 'SUCCESS',
  2: 'FAIL',
};
