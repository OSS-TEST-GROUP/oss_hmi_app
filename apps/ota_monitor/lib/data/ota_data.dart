// OTA Manager topic and message type definitions for rosbridge (websocket)
// OTA Manager publishes responses and subscribes requests on rt/mmf/... DDS topics
// which correspond to /mmf/... ROS2 topic names used by rosbridge.

const String _pkg = 'otamanager/msg';

// Response topics (subscribe via rosbridge)
const List<String> otaResponseTopics = [
  '/mmf/otamanager/otaactor_service/GetAppUpdateSettingsResponse',
  '/mmf/otamanager/otaactor_service/SetAppUpdateSettingsResponse',
  '/mmf/otamanager/otaactor_service/GetAppUpdateStateResponse',
  '/mmf/otamanager/otaactor_service/SetAppUpdateResponse',
  '/mmf/otamanager/otaclient_service/NotifyAppUpdateStatus',
];

// Request topics (publish via rosbridge)
const List<String> otaRequestTopics = [
  '/mmf/otamanager/otaactor_service/GetAppUpdateSettings',
  '/mmf/otamanager/otaactor_service/SetAppUpdateSettings',
  '/mmf/otamanager/otaactor_service/GetAppUpdateState',
  '/mmf/otamanager/otaactor_service/SetAppUpdate',
];

// ROS2 message type names (otamanager/msg/TypeName)
const List<String> otaRosResponseTypes = [
  '$_pkg/GetAppUpdateSettingsResponse',
  '$_pkg/SetAppUpdateSettingsResponse',
  '$_pkg/GetAppUpdateStateResponse',
  '$_pkg/SetAppUpdateResponse',
  '$_pkg/NotifyAppUpdateStatus',
];

const List<String> otaRosRequestTypes = [
  '$_pkg/GetAppUpdateSettings',
  '$_pkg/SetAppUpdateSettings',
  '$_pkg/GetAppUpdateState',
  '$_pkg/SetAppUpdate',
];

// GetAppList query topics. Relocated from otaclient_service to
// otaactor_service so ota_monitor talks to actor exclusively for
// these queries. IDL definition now lives in OtamActorServiceMsg.idl.
const String otaGetAppListReqTopic =
    '/mmf/otamanager/otaactor_service/GetAppList';
const String otaGetAppListResTopic =
    '/mmf/otamanager/otaactor_service/GetAppListResponse';
const String otaGetAppListReqType = '$_pkg/GetAppList';
const String otaGetAppListResType = '$_pkg/GetAppListResponse';

// DeleteOtaClientRegistration — operator-driven removal of an entire
// client (and all its apps) from the Manager's persisted registry.
// Addressed by client_id.
const String otaDeleteClientReqTopic =
    '/mmf/otamanager/otaactor_service/DeleteOtaClientRegistration';
const String otaDeleteClientResTopic =
    '/mmf/otamanager/otaactor_service/DeleteOtaClientRegistrationResponse';
const String otaDeleteClientReqType = '$_pkg/DeleteOtaClientRegistration';
const String otaDeleteClientResType = '$_pkg/DeleteOtaClientRegistrationResponse';

// ReturnValue enum (matches otamanager/msg/ReturnValue)
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
