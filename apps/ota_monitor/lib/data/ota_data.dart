// OTA Manager 토픽 및 메시지 타입 정의

// Response 토픽 목록 (구독)
const List<String> otaResponseTopics = [
  '/mmf/otamanager/otaactor_service/GetAppUpdateSettingsResponse',
  '/mmf/otamanager/otaactor_service/SetAppUpdateSettingsResponse',
  '/mmf/otamanager/otaactor_service/GetAppUpdateStateResponse',
  '/mmf/otamanager/otaactor_service/SetAppUpdateResponse',
  '/mmf/otamanager/otaclient_service/NotifyAppUpdateStatus',
];

// Request 토픽 목록 (발행)
const List<String> otaRequestTopics = [
  '/mmf/otamanager/otaactor_service/GetAppUpdateSettings',
  '/mmf/otamanager/otaactor_service/SetAppUpdateSettings',
  '/mmf/otamanager/otaactor_service/GetAppUpdateState',
  '/mmf/otamanager/otaactor_service/SetAppUpdate',
];

// 메시지 타입 (WebSocket 브릿지에서 사용)
const List<String> otaResponseTypes = [
  'ota_manager/GetAppUpdateSettingsResponse',
  'ota_manager/SetAppUpdateSettingsResponse',
  'ota_manager/GetAppUpdateStateResponse',
  'ota_manager/SetAppUpdateResponse',
  'ota_manager/NotifyAppUpdateStatus',
];

const List<String> otaRequestTypes = [
  'ota_manager/GetAppUpdateSettings',
  'ota_manager/SetAppUpdateSettings',
  'ota_manager/GetAppUpdateState',
  'ota_manager/SetAppUpdate',
];

// ReturnValue 열거형 (DDS IDL에서 정의)
enum ReturnValue {
  UNKNOWN(0),
  SUCCESS(1),
  FAIL(2);

  const ReturnValue(this.value);
  final int value;

  static ReturnValue fromInt(int? val) {
    switch (val) {
      case 1:
        return ReturnValue.SUCCESS;
      case 2:
        return ReturnValue.FAIL;
      default:
        return ReturnValue.UNKNOWN;
    }
  }
}

// 상태 텍스트 매핑
const Map<int, String> returnValueText = {
  0: 'UNKNOWN',
  1: 'SUCCESS',
  2: 'FAIL',
};
