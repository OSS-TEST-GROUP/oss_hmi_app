#ifndef DDS_OTA_BRIDGE_H
#define DDS_OTA_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Callback type invoked when a DDS message is received.
 * @param topic  DDS topic name (e.g. "rt/mmf/otamanager/...")
 * @param json   JSON string of the received message fields
 */
typedef void (*dds_msg_callback_t)(const char* topic, const char* json);

/**
 * Initialize the DDS bridge with the given domain ID.
 * Creates a shared DomainParticipant, Publisher, and Subscriber.
 * @param domain_id  DDS domain (OTA Manager uses 0)
 * @return 0 on success, negative on error
 */
int dds_ota_init(int domain_id);

/**
 * Subscribe to a DDS topic.
 * The callback is invoked from a background listener thread whenever a
 * message arrives.  The Dart side must use NativeCallable.listener so the
 * call is safely marshalled onto the Flutter isolate.
 *
 * @param topic_name  Full DDS topic name (with rt/ prefix)
 * @param type_name   DDS type name, e.g. "ota_manager::msg::GetAppUpdateSettingsResponse"
 * @param callback    Function pointer to call on message receipt
 * @return 0 on success, negative on error
 */
int dds_ota_subscribe(const char* topic_name,
                      const char* type_name,
                      dds_msg_callback_t callback);

/**
 * Publish a JSON-encoded message to a DDS topic.
 * @param topic_name  Full DDS topic name
 * @param type_name   DDS type name
 * @param json        JSON string, e.g. {"id":1,"app_name":"foo"}
 * @return 0 on success, negative on error
 */
int dds_ota_publish(const char* topic_name,
                    const char* type_name,
                    const char* json);

/**
 * Release all DDS resources created by dds_ota_init / dds_ota_subscribe /
 * dds_ota_publish.
 */
void dds_ota_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* DDS_OTA_BRIDGE_H */
