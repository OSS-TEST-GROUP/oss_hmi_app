#include "llm_provider.hpp"
#include "llm_provider_llamacpp.hpp"
#include "multimodal_types.hpp"
#include "rag_engine.hpp"
#include <algorithm>
#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <cstring>
#include <cstdlib>
#include <mutex>
#include <vector>

struct ChatbotHandle {
    std::shared_ptr<ai_common::ILLMProvider> provider;
    std::shared_ptr<ai_common::LlamaCppProvider> llama;
    std::mutex metrics_mutex;
    int last_tokens = 0;
    float last_generation_time_ms = 0.0f;
    float last_first_token_time_ms = 0.0f;
};

namespace {

constexpr const char* kSystemPrompt =
    "당신은 차량용 런처봇입니다. 한국어로 한 문장만 답하세요. "
    "앱 실행 요청은 실행하겠다고 짧게 확인하세요. "
    "사용자의 말을 그대로 따라 쓰지 마세요.";

std::string build_gemma4_prompt(const char* prompt) {
    std::string user_prompt = prompt ? prompt : "";

    return std::string("<|turn>system\n") +
           kSystemPrompt +
           "<turn|>\n"
           "<|turn>user\n" +
           user_prompt +
           "<turn|>\n"
           "<|turn>model\n";
}

std::string trim(const std::string& value) {
    const auto start = value.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) {
        return "";
    }
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(start, end - start + 1);
}

std::string clean_response(const std::string& content) {
    std::string out = content;

    const std::vector<std::string> prefix_markers = {
        "<|channel>final\n",
        "<channel|>",
    };
    for (const auto& marker : prefix_markers) {
        const auto pos = out.find(marker);
        if (pos != std::string::npos) {
            out = out.substr(pos + marker.size());
        }
    }

    const std::vector<std::string> stop_markers = {
        "<turn|>",
        "<|turn>",
        "<|channel>",
        "<start_of_turn>",
        "</start_of_turn>",
        "<end_of_turn>",
        "</end_of_turn>",
        "<|im_start|>",
        "<|im_end|>",
    };
    size_t stop = std::string::npos;
    for (const auto& marker : stop_markers) {
        const auto pos = out.find(marker);
        if (pos != std::string::npos && (stop == std::string::npos || pos < stop)) {
            stop = pos;
        }
    }
    if (stop != std::string::npos) {
        out = out.substr(0, stop);
    }

    return trim(out);
}

char* copy_string(const std::string& out) {
    char* ret = static_cast<char*>(std::malloc(out.size() + 1));
    if (!ret) {
        return nullptr;
    }
    std::memcpy(ret, out.c_str(), out.size() + 1);
    return ret;
}

void update_metrics(ChatbotHandle* h, const ai_common::GenerateResponse& res) {
    std::lock_guard<std::mutex> lock(h->metrics_mutex);
    h->last_tokens = res.tokens_used;
    h->last_generation_time_ms = res.generation_time_ms;
    h->last_first_token_time_ms = res.first_token_time_ms;
}

[[maybe_unused]] std::string error_message_to_string(const std::string& error_message) {
    return error_message;
}

[[maybe_unused]] std::string error_message_to_string(const std::optional<std::string>& error_message) {
    return error_message.value_or("");
}

[[maybe_unused]] size_t error_message_size(const std::string& error_message) {
    return error_message.size();
}

[[maybe_unused]] size_t error_message_size(const std::optional<std::string>& error_message) {
    return error_message ? error_message->size() : 0;
}

[[maybe_unused]] std::string string_value(const std::string& value) {
    return value;
}

[[maybe_unused]] std::string string_value(const std::optional<std::string>& value) {
    return value.value_or("");
}

[[maybe_unused]] size_t string_value_size(const std::string& value) {
    return value.size();
}

[[maybe_unused]] size_t string_value_size(const std::optional<std::string>& value) {
    return value ? value->size() : 0;
}

}  // namespace

extern "C" {

ChatbotHandle* chatbot_create(const char* config_path) {
    auto provider = ai_common::LLMProviderFactory::create_from_json(config_path);
    if (!provider) return nullptr;
    auto llama = std::dynamic_pointer_cast<ai_common::LlamaCppProvider>(provider);
    return new ChatbotHandle{provider, llama};
}

char* chatbot_generate(ChatbotHandle* h, const char* prompt) {
    if (!h || !h->provider) return nullptr;

    ai_common::GenerateRequest req;
    req.user_prompt = build_gemma4_prompt(prompt);
    req.max_tokens = 96;
    req.temperature = 0.4f;
    req.top_p = 0.9f;
    req.top_k = 40;

    auto res = h->provider->generate(req);
    update_metrics(h, res);
    const std::string out = res.success
        ? clean_response(string_value(res.content))
        : error_message_to_string(res.error_message);
    return copy_string(out);
}

int chatbot_has_audio(ChatbotHandle* h) {
    return (h && h->llama) ? 1 : 0;
}

char* chatbot_generate_audio_f32(
    ChatbotHandle* h,
    const char* prompt,
    const float* pcm,
    int sample_count,
    int sample_rate,
    int channels) {
    if (!h || !h->llama || !pcm || sample_count <= 0 || sample_rate <= 0 || channels <= 0) {
        std::cerr << "[chatbot_bridge] generate_audio_f32 invalid input: "
                  << "has_handle=" << (h != nullptr)
                  << ", has_llama=" << (h && h->llama)
                  << ", has_pcm=" << (pcm != nullptr)
                  << ", sample_count=" << sample_count
                  << ", sample_rate=" << sample_rate
                  << ", channels=" << channels
                  << std::endl;
        return nullptr;
    }

    ai_common::GenerateRequest req;
    req.user_prompt = "이 오디오를 한국어 텍스트로 정확히 받아쓰기해줘. "
                      "차량 명령이면 의도도 짧게 정리해줘. "
                      "특수 토큰이나 turn marker는 출력하지 마.";
    req.max_tokens = 128;
    req.temperature = 0.2f;
    req.top_p = 0.9f;
    req.top_k = 40;

    ai_common::MultimodalContent content;
    content.text = prompt && std::strlen(prompt) > 0 ? prompt : req.user_prompt;
    content.audio = std::vector<float>(pcm, pcm + sample_count);
    content.audio_sample_rate = sample_rate;
    content.audio_channels = channels;

    std::cerr << "[chatbot_bridge] generate_audio_f32 start: "
              << "sample_count=" << sample_count
              << ", sample_rate=" << sample_rate
              << ", channels=" << channels
              << ", prompt_size=" << string_value_size(content.text)
              << std::endl;

    auto res = h->llama->generate_multimodal(req, content);
    std::cerr << "[chatbot_bridge] generate_audio_f32 result: "
              << "success=" << res.success
              << ", content_size=" << string_value_size(res.content)
              << ", error_size=" << error_message_size(res.error_message)
              << ", tokens=" << res.tokens_used
              << ", generation_time_ms=" << res.generation_time_ms
              << ", ttft_ms=" << res.first_token_time_ms
              << std::endl;
    const std::string error_message = error_message_to_string(res.error_message);
    if (!res.success && !error_message.empty()) {
        std::cerr << "[chatbot_bridge] generate_audio_f32 error: "
                  << error_message << std::endl;
    }

    update_metrics(h, res);
    const std::string raw_content = string_value(res.content);
    const std::string out = res.success ? clean_response(raw_content) : error_message;
    if (res.success) {
        std::cerr << "[chatbot_bridge] generate_audio_f32 raw_content: ["
                  << raw_content.substr(0, 500) << "]" << std::endl;
        std::cerr << "[chatbot_bridge] generate_audio_f32 cleaned_content: ["
                  << out.substr(0, 500) << "]" << std::endl;
    }
    return copy_string(out);
}

char* chatbot_generate_with_contexts(
    ChatbotHandle* h,
    const char* prompt,
    const char** contexts,
    int context_count) {
    if (!h || !h->provider) return nullptr;

    ai_common::GenerateRequest req;
    req.user_prompt = build_gemma4_prompt(prompt);
    req.max_tokens = 128;
    req.temperature = 0.4f;
    req.top_p = 0.9f;
    req.top_k = 40;

    const int safe_count = std::max(0, context_count);
    for (int i = 0; i < safe_count; ++i) {
        if (contexts && contexts[i] && std::strlen(contexts[i]) > 0) {
            req.contexts.emplace_back(contexts[i]);
        }
    }

    auto res = h->provider->generate(req);
    update_metrics(h, res);
    const std::string out = res.success
        ? clean_response(string_value(res.content))
        : error_message_to_string(res.error_message);
    return copy_string(out);
}

int chatbot_last_tokens(ChatbotHandle* h) {
    if (!h) return 0;
    std::lock_guard<std::mutex> lock(h->metrics_mutex);
    return h->last_tokens;
}

float chatbot_last_generation_time_ms(ChatbotHandle* h) {
    if (!h) return 0.0f;
    std::lock_guard<std::mutex> lock(h->metrics_mutex);
    return h->last_generation_time_ms;
}

float chatbot_last_first_token_time_ms(ChatbotHandle* h) {
    if (!h) return 0.0f;
    std::lock_guard<std::mutex> lock(h->metrics_mutex);
    return h->last_first_token_time_ms;
}

void chatbot_free_string(char* s) {
    std::free(s);
}

void chatbot_destroy(ChatbotHandle* h) {
    delete h;
}

}
