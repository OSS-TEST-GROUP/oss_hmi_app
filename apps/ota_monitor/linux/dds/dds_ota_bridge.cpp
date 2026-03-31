/**
 * dds_ota_bridge.cpp
 *
 * C bridge between Flutter/Dart and FastDDS for the OTA Monitor.
 * Provides publish/subscribe over the same FastDDS topics used by OTA Manager.
 *
 * CDR encoding: XCDR v1 (plain CDR, little-endian)
 *   – forced via DataWriterQos / DataReaderQos representation policy so both
 *     sides negotiate XCDR v1, simplifying hand-written CDR serialisation.
 */

#include "dds_ota_bridge.h"

#include <fastdds/dds/domain/DomainParticipant.hpp>
#include <fastdds/dds/domain/DomainParticipantFactory.hpp>
#include <fastdds/dds/publisher/Publisher.hpp>
#include <fastdds/dds/publisher/DataWriter.hpp>
#include <fastdds/dds/publisher/qos/DataWriterQos.hpp>
#include <fastdds/dds/subscriber/Subscriber.hpp>
#include <fastdds/dds/subscriber/DataReader.hpp>
#include <fastdds/dds/subscriber/DataReaderListener.hpp>
#include <fastdds/dds/subscriber/qos/DataReaderQos.hpp>
#include <fastdds/dds/subscriber/SampleInfo.hpp>
#include <fastdds/dds/topic/Topic.hpp>
#include <fastdds/dds/topic/TopicDataType.hpp>
#include <fastdds/dds/topic/TypeSupport.hpp>
#include <fastdds/rtps/common/SerializedPayload.hpp>
#include <fastdds/rtps/common/InstanceHandle.hpp>

#include <fastcdr/FastBuffer.h>
#include <fastcdr/Cdr.h>

#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace fddsdds = eprosima::fastdds::dds;
namespace frtps   = eprosima::fastdds::rtps;

// ============================================================================
// Minimal JSON helpers (no external dependency)
// ============================================================================

static std::string json_escape(const std::string& s) {
    std::string out;
    out.reserve(s.size() + 4);
    for (char c : s) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:   out += c;      break;
        }
    }
    return out;
}

// Extract string value for a key from a simple flat JSON object.
static bool json_get_string(const std::string& json, const std::string& key,
                             std::string& out) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return false;
    pos += needle.size();
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == ':')) pos++;
    if (pos >= json.size() || json[pos] != '"') return false;
    pos++;
    size_t end = json.find('"', pos);
    if (end == std::string::npos) return false;
    out = json.substr(pos, end - pos);
    return true;
}

// Extract integer value for a key.
static bool json_get_int(const std::string& json, const std::string& key,
                          int32_t& out) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return false;
    pos += needle.size();
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == ':')) pos++;
    if (pos >= json.size()) return false;
    try {
        size_t n;
        long v = std::stol(json.substr(pos), &n);
        out = static_cast<int32_t>(v);
        return true;
    } catch (...) {
        return false;
    }
}

// ============================================================================
// CDR serialisation helpers using fastcdr
// ============================================================================

// Return the unqualified type name (strip any C++ namespace prefix).
// "OtaManager::GetAppUpdateSettings"   → "GetAppUpdateSettings"
// "ota_manager::msg::GetAppUpdateSettings" → "GetAppUpdateSettings"
static std::string type_base_name(const std::string& type_name) {
    size_t pos = type_name.rfind("::");
    return (pos != std::string::npos) ? type_name.substr(pos + 2) : type_name;
}

// Write XCDR-v1 CDR from JSON according to type_name.
// Returns serialised bytes (including 4-byte encapsulation header) or empty on error.
static std::vector<uint8_t> json_to_cdr(const std::string& type_name,
                                         const std::string& json) {
    // Allocate a generous working buffer.
    static const size_t kBufSize = 4096;
    std::vector<uint8_t> buf(kBufSize, 0);

    eprosima::fastcdr::FastBuffer fb(reinterpret_cast<char*>(buf.data()), kBufSize);
    eprosima::fastcdr::Cdr ser(fb,
        eprosima::fastcdr::Cdr::LITTLE_ENDIANNESS,
        eprosima::fastcdr::CdrVersion::XCDRv1);
    ser.serialize_encapsulation();

    const std::string base = type_base_name(type_name);
    try {
        // --- GetAppUpdateSettings ---
        // {id:int32, app_name:string}
        if (base == "GetAppUpdateSettings") {
            int32_t id = 0;
            std::string app_name;
            json_get_int(json, "id", id);
            json_get_string(json, "app_name", app_name);
            ser.serialize(id);
            ser.serialize(app_name);
        }
        // --- SetAppUpdateSettings ---
        // {id:int32, app_name:string, app_settings:string}
        else if (base == "SetAppUpdateSettings") {
            int32_t id = 0;
            std::string app_name, app_settings;
            json_get_int(json, "id", id);
            json_get_string(json, "app_name", app_name);
            json_get_string(json, "app_settings", app_settings);
            ser.serialize(id);
            ser.serialize(app_name);
            ser.serialize(app_settings);
        }
        // --- GetAppUpdateState ---
        // {id:int32, app_name:string}
        else if (base == "GetAppUpdateState") {
            int32_t id = 0;
            std::string app_name;
            json_get_int(json, "id", id);
            json_get_string(json, "app_name", app_name);
            ser.serialize(id);
            ser.serialize(app_name);
        }
        // --- SetAppUpdate ---
        // {id:int32, app_name:string}
        else if (base == "SetAppUpdate") {
            int32_t id = 0;
            std::string app_name;
            json_get_int(json, "id", id);
            json_get_string(json, "app_name", app_name);
            ser.serialize(id);
            ser.serialize(app_name);
        }
        // Fallback: nothing to serialise
        else {
            (void)json;
        }
    } catch (...) {
        return {};
    }

    size_t len = ser.get_serialized_data_length();
    buf.resize(len);
    return buf;
}

// Parse CDR bytes according to type_name, produce JSON string.
// Handles both XCDR v1 (CDR_LE/CDR_BE) and XCDR v2 (PLAIN_CDR2/DELIMIT_CDR2).
static std::string cdr_to_json(const std::string& type_name,
                                const uint8_t* data, size_t len) {
    if (len < 4) return "{}";

    eprosima::fastcdr::FastBuffer fb(
        reinterpret_cast<char*>(const_cast<uint8_t*>(data)), len);
    // Let fastcdr pick the version after read_encapsulation()
    eprosima::fastcdr::Cdr cdr(fb, eprosima::fastcdr::Cdr::DEFAULT_ENDIAN);
    try {
        cdr.read_encapsulation();
    } catch (...) {
        std::fprintf(stderr, "[dds_ota] cdr_to_json: read_encapsulation failed "
                     "(type=%s len=%zu hdr=%02x%02x%02x%02x)\n",
                     type_name.c_str(), len, data[0], data[1], data[2], data[3]);
        return "{}";
    }

    // For XCDR v2 (DELIMIT_CDR2), the struct body starts with a DHEADER.
    // Use deserialize_type() or skip DHEADER manually.
    bool is_xcdr2 = (cdr.get_cdr_version() == eprosima::fastcdr::CdrVersion::XCDRv2);
    if (is_xcdr2) {
        // DHEADER: uint32 length of the following type data; skip it.
        try {
            uint32_t dheader = 0;
            cdr.deserialize(dheader);
        } catch (...) { return "{}"; }
    }

    const std::string base = type_base_name(type_name);
    char buf[4096] = {};
    try {
        // --- GetAppUpdateSettingsResponse ---
        // {id:int32, app_name:string, app_settings:string, ret_code:int32}
        if (base == "GetAppUpdateSettingsResponse") {
            int32_t id = 0, ret_code = 0;
            std::string app_name, app_settings;
            cdr.deserialize(id);
            cdr.deserialize(app_name);
            cdr.deserialize(app_settings);
            cdr.deserialize(ret_code);
            std::snprintf(buf, sizeof(buf),
                "{\"id\":%d,\"app_name\":\"%s\",\"app_settings\":\"%s\",\"ret_code\":%d}",
                id,
                json_escape(app_name).c_str(),
                json_escape(app_settings).c_str(),
                ret_code);
        }
        // --- SetAppUpdateSettingsResponse ---
        // {id:int32, ret_code:int32}
        else if (base == "SetAppUpdateSettingsResponse") {
            int32_t id = 0, ret_code = 0;
            cdr.deserialize(id);
            cdr.deserialize(ret_code);
            std::snprintf(buf, sizeof(buf),
                "{\"id\":%d,\"ret_code\":%d}", id, ret_code);
        }
        // --- GetAppUpdateStateResponse ---
        // {id:int32, app_name:string, app_state_info:string, ret_code:int32}
        else if (base == "GetAppUpdateStateResponse") {
            int32_t id = 0, ret_code = 0;
            std::string app_name, app_state_info;
            cdr.deserialize(id);
            cdr.deserialize(app_name);
            cdr.deserialize(app_state_info);
            cdr.deserialize(ret_code);
            std::snprintf(buf, sizeof(buf),
                "{\"id\":%d,\"app_name\":\"%s\",\"app_state_info\":\"%s\",\"ret_code\":%d}",
                id,
                json_escape(app_name).c_str(),
                json_escape(app_state_info).c_str(),
                ret_code);
        }
        // --- SetAppUpdateResponse ---
        // {id:int32, app_name:string, ret_code:int32}
        else if (base == "SetAppUpdateResponse") {
            int32_t id = 0, ret_code = 0;
            std::string app_name;
            cdr.deserialize(id);
            cdr.deserialize(app_name);
            cdr.deserialize(ret_code);
            std::snprintf(buf, sizeof(buf),
                "{\"id\":%d,\"app_name\":\"%s\",\"ret_code\":%d}",
                id, json_escape(app_name).c_str(), ret_code);
        }
        // --- NotifyAppUpdateStatus ---
        // {client_id:int32, app_name:string, status:string}
        else if (base == "NotifyAppUpdateStatus") {
            int32_t client_id = 0;
            std::string app_name, status;
            cdr.deserialize(client_id);
            cdr.deserialize(app_name);
            cdr.deserialize(status);
            std::snprintf(buf, sizeof(buf),
                "{\"client_id\":%d,\"app_name\":\"%s\",\"status\":\"%s\"}",
                client_id,
                json_escape(app_name).c_str(),
                json_escape(status).c_str());
        }
        // --- NotifyOtaMgrInfo ---
        // {err_code:int32, err_msg:string}
        else if (base == "NotifyOtaMgrInfo") {
            int32_t err_code = 0;
            std::string err_msg;
            cdr.deserialize(err_code);
            cdr.deserialize(err_msg);
            std::snprintf(buf, sizeof(buf),
                "{\"err_code\":%d,\"err_msg\":\"%s\"}",
                err_code, json_escape(err_msg).c_str());
        }
        else {
            std::snprintf(buf, sizeof(buf), "{}");
        }
    } catch (...) {
        std::snprintf(buf, sizeof(buf), "{}");
    }
    return std::string(buf);
}

// ============================================================================
// GenericPubSubType – stores raw CDR bytes (including encapsulation header)
// ============================================================================

class GenericPubSubType : public fddsdds::TopicDataType {
public:
    explicit GenericPubSubType(const std::string& name) {
        set_name(name);
        max_serialized_type_size = 65536;
        // Generated IDL types set is_compute_key_provided = true; mismatch causes
        // FastDDS valid_matching() to reject the endpoint pair (inconsistent_topic).
        is_compute_key_provided  = true;
    }

    ~GenericPubSubType() override = default;

    bool serialize(const void* data,
                   frtps::SerializedPayload_t& payload,
                   fddsdds::DataRepresentationId_t /*repr*/) override {
        auto* v = static_cast<const std::vector<uint8_t>*>(data);
        if (payload.max_size < v->size()) return false;
        std::memcpy(payload.data, v->data(), v->size());
        payload.length = static_cast<uint32_t>(v->size());
        payload.encapsulation = CDR_LE;
        return true;
    }

    bool deserialize(frtps::SerializedPayload_t& payload, void* data) override {
        auto* v = static_cast<std::vector<uint8_t>*>(data);
        v->assign(payload.data, payload.data + payload.length);
        return true;
    }

    uint32_t calculate_serialized_size(
            const void* data,
            fddsdds::DataRepresentationId_t /*repr*/) override {
        auto* v = static_cast<const std::vector<uint8_t>*>(data);
        return static_cast<uint32_t>(v->size());
    }

    void* create_data() override {
        return static_cast<void*>(new std::vector<uint8_t>());
    }

    void delete_data(void* data) override {
        delete static_cast<std::vector<uint8_t>*>(data);
    }

    bool compute_key(frtps::SerializedPayload_t& /*payload*/,
                     frtps::InstanceHandle_t& /*ihandle*/,
                     bool /*force_md5*/) override {
        return false;
    }

    bool compute_key(const void* /*data*/,
                     frtps::InstanceHandle_t& /*ihandle*/,
                     bool /*force_md5*/) override {
        return false;
    }
};

// ============================================================================
// Subscriber listener – converts CDR payload to JSON and calls Dart callback
// ============================================================================

struct TopicEntry;  // forward

class GenericListener : public fddsdds::DataReaderListener {
public:
    GenericListener(std::string topic, std::string type_name,
                    dds_msg_callback_t cb)
        : topic_(std::move(topic))
        , type_name_(std::move(type_name))
        , callback_(cb) {}

    void on_data_available(fddsdds::DataReader* reader) override {
        std::vector<uint8_t> raw;
        fddsdds::SampleInfo info;

        while (reader->take_next_sample(&raw, &info) == fddsdds::RETCODE_OK) {
            if (!info.valid_data) continue;
            if (raw.empty()) continue;

            std::string json = cdr_to_json(type_name_,
                                           raw.data(), raw.size());
            if (callback_) {
                callback_(topic_.c_str(), json.c_str());
            }
        }
    }

private:
    std::string         topic_;
    std::string         type_name_;
    dds_msg_callback_t  callback_;
};

// ============================================================================
// Per-topic resources
// ============================================================================

struct TopicEntry {
    std::unique_ptr<GenericPubSubType> pub_sub_type;
    fddsdds::Topic*                    topic      = nullptr;
    fddsdds::DataWriter*               writer     = nullptr;
    fddsdds::DataReader*               reader     = nullptr;
    std::unique_ptr<GenericListener>   listener;
    std::string                        type_name;
};

// ============================================================================
// Bridge singleton
// ============================================================================

struct OtaBridge {
    fddsdds::DomainParticipant* participant = nullptr;
    fddsdds::Publisher*         publisher   = nullptr;
    fddsdds::Subscriber*        subscriber  = nullptr;

    std::mutex                           mtx;
    std::map<std::string, TopicEntry>    topics; // key = topic_name

    ~OtaBridge() { cleanup(); }

    void cleanup() {
        std::lock_guard<std::mutex> lk(mtx);
        if (!participant) return;

        for (auto& [name, e] : topics) {
            if (e.reader) { subscriber->delete_datareader(e.reader); e.reader = nullptr; }
            if (e.writer) { publisher->delete_datawriter(e.writer);  e.writer = nullptr; }
            if (e.topic)  { participant->delete_topic(e.topic);       e.topic  = nullptr; }
        }
        topics.clear();

        participant->delete_contained_entities();
        fddsdds::DomainParticipantFactory::get_instance()->delete_participant(participant);
        participant = nullptr;
        publisher   = nullptr;
        subscriber  = nullptr;
    }

    // Ensure a TypeSupport is registered and a Topic exists.
    // Returns pointer to entry (inside map, stable reference), or nullptr on error.
    TopicEntry* ensure_topic(const std::string& topic_name,
                              const std::string& type_name) {
        auto it = topics.find(topic_name);
        if (it != topics.end()) return &it->second;

        TopicEntry e;
        e.type_name = type_name;
        e.pub_sub_type = std::make_unique<GenericPubSubType>(type_name);

        // Register TypeSupport (safe to call multiple times for same name)
        {
            auto* raw = e.pub_sub_type.get();
            fddsdds::TypeSupport ts;
            static_cast<std::shared_ptr<fddsdds::TopicDataType>&>(ts)
                .reset(raw, [](fddsdds::TopicDataType*) {});
            if (ts.register_type(participant) != fddsdds::RETCODE_OK) {
                // May already be registered – ignore the error
            }
        }

        e.topic = participant->create_topic(
            topic_name, type_name, fddsdds::TOPIC_QOS_DEFAULT);
        if (!e.topic) {
            std::fprintf(stderr, "[dds_ota] Failed to create topic: %s\n",
                         topic_name.c_str());
            return nullptr;
        }

        topics.emplace(topic_name, std::move(e));
        return &topics.at(topic_name);
    }
};

static OtaBridge g_bridge;

// ============================================================================
// C API implementation
// ============================================================================

extern "C" {

int dds_ota_init(int domain_id) {
    std::lock_guard<std::mutex> lk(g_bridge.mtx);
    if (g_bridge.participant) return 0;  // already initialised

    auto* factory = fddsdds::DomainParticipantFactory::get_instance();
    g_bridge.participant = factory->create_participant(
        domain_id, fddsdds::PARTICIPANT_QOS_DEFAULT);
    if (!g_bridge.participant) {
        std::fprintf(stderr, "[dds_ota] Failed to create participant\n");
        return -1;
    }

    g_bridge.publisher = g_bridge.participant->create_publisher(
        fddsdds::PUBLISHER_QOS_DEFAULT, nullptr);
    if (!g_bridge.publisher) {
        std::fprintf(stderr, "[dds_ota] Failed to create publisher\n");
        fddsdds::DomainParticipantFactory::get_instance()
            ->delete_participant(g_bridge.participant);
        g_bridge.participant = nullptr;
        return -2;
    }

    g_bridge.subscriber = g_bridge.participant->create_subscriber(
        fddsdds::SUBSCRIBER_QOS_DEFAULT, nullptr);
    if (!g_bridge.subscriber) {
        std::fprintf(stderr, "[dds_ota] Failed to create subscriber\n");
        g_bridge.participant->delete_contained_entities();
        fddsdds::DomainParticipantFactory::get_instance()
            ->delete_participant(g_bridge.participant);
        g_bridge.participant = nullptr;
        g_bridge.publisher   = nullptr;
        return -3;
    }

    std::fprintf(stderr, "[dds_ota] Initialised (domain %d)\n", domain_id);
    return 0;
}

int dds_ota_subscribe(const char* topic_name,
                      const char* type_name,
                      dds_msg_callback_t callback) {
    if (!topic_name || !type_name || !callback) return -1;

    std::lock_guard<std::mutex> lk(g_bridge.mtx);
    if (!g_bridge.participant) return -2;

    TopicEntry* e = g_bridge.ensure_topic(topic_name, type_name);
    if (!e) return -3;

    // Already subscribed?
    if (e->reader) return 0;

    e->listener = std::make_unique<GenericListener>(topic_name, type_name, callback);

    fddsdds::DataReaderQos rqos = fddsdds::DATAREADER_QOS_DEFAULT;
    rqos.reliability().kind = fddsdds::RELIABLE_RELIABILITY_QOS;

    e->reader = g_bridge.subscriber->create_datareader(
        e->topic, rqos, e->listener.get());
    if (!e->reader) {
        std::fprintf(stderr, "[dds_ota] Failed to create reader: %s\n", topic_name);
        return -4;
    }

    std::fprintf(stderr, "[dds_ota] Subscribed: %s\n", topic_name);
    return 0;
}

int dds_ota_publish(const char* topic_name,
                    const char* type_name,
                    const char* json) {
    if (!topic_name || !type_name || !json) return -1;

    std::lock_guard<std::mutex> lk(g_bridge.mtx);
    if (!g_bridge.participant) return -2;

    TopicEntry* e = g_bridge.ensure_topic(topic_name, type_name);
    if (!e) return -3;

    // Create writer on first publish.
    if (!e->writer) {
        fddsdds::DataWriterQos wqos = fddsdds::DATAWRITER_QOS_DEFAULT;
        wqos.reliability().kind = fddsdds::RELIABLE_RELIABILITY_QOS;

        e->writer = g_bridge.publisher->create_datawriter(e->topic, wqos);
        if (!e->writer) {
            std::fprintf(stderr, "[dds_ota] Failed to create writer: %s\n",
                         topic_name);
            return -4;
        }
    }

    std::string js(json);
    std::string tn(type_name);
    std::vector<uint8_t> cdr = json_to_cdr(tn, js);
    if (cdr.empty()) {
        std::fprintf(stderr, "[dds_ota] CDR serialisation failed for %s\n",
                     type_name);
        return -5;
    }

    auto rc = e->writer->write(&cdr);
    if (rc != fddsdds::RETCODE_OK) {
        std::fprintf(stderr, "[dds_ota] write() failed: %s\n", topic_name);
        return -6;
    }

    return 0;
}

void dds_ota_cleanup(void) {
    g_bridge.cleanup();
    std::fprintf(stderr, "[dds_ota] Cleanup done\n");
}

} // extern "C"
