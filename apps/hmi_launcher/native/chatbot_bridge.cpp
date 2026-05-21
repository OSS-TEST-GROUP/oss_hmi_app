#include "llm_provider.hpp"
#include "llm_provider_llamacpp.hpp"
#include "multimodal_types.hpp"
#include "rag_engine.hpp"
#include <algorithm>
#include <filesystem>
#include <fstream>
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
    std::unique_ptr<ai_rag::RAGEngine> rag;
    std::mutex rag_mutex;
    bool rag_ready = false;
    std::mutex metrics_mutex;
    int last_tokens = 0;
    float last_generation_time_ms = 0.0f;
    float last_first_token_time_ms = 0.0f;
};

namespace {

constexpr size_t kRagMaxContextChars = 260;
constexpr size_t kRagMaxSingleContextChars = 260;
constexpr int kRagMaxContexts = 1;
constexpr int kRagMaxOutputTokens = 64;

constexpr const char* kSystemPrompt =
    "당신은 AGL 차량용 HMI 런처의 한국어 AI 어시스턴트입니다. "
    "사용자의 의도와 상황에 맞게 필요한 만큼 자연스럽게 답하세요. "
    "모르는 내용은 추측하지 말고 확인이 필요하다고 말하세요. "
    "앱 실행, 설정 열기, 앱 닫기는 런처가 이미 처리하므로 일반 질문에는 설명이나 안내만 답하세요.";

// Gemma's chat format has no system role: any system content is folded into
// the first user turn. Real tokens are <start_of_turn>/<end_of_turn>; the
// homemade <|turn>...<turn|> sequence the bridge used previously is parsed by
// Gemma as plain text, which makes the model fall into completion mode and
// echo back fake markdown labels like **사용자 질문** / **답변**.
std::string build_gemma4_prompt(const char* prompt) {
    const std::string user_prompt = prompt ? prompt : "";

    return std::string("<start_of_turn>user\n") +
           kSystemPrompt + "\n\n" +
           user_prompt +
           "<end_of_turn>\n"
           "<start_of_turn>model\n";
}

std::string build_gemma4_rag_prompt(const char* prompt) {
    const std::string user_prompt = prompt ? prompt : "";

    return std::string("<start_of_turn>user\n") +
           "차량 가이드 발췌에 근거해 짧게 답하세요. 근거가 없으면 없다고 말하세요.\n\n" +
           user_prompt +
           "<end_of_turn>\n"
           "<start_of_turn>model\n";
}

std::string build_rag_user_prompt(
    const char* question,
    const std::vector<std::string>& contexts) {
    const std::string q = question ? question : "";
    if (contexts.empty()) {
        return q;
    }

    std::string prompt = "[가이드 발췌]\n";

    for (size_t i = 0; i < contexts.size(); ++i) {
        prompt += "\n--- 문서 " + std::to_string(i + 1) + " ---\n";
        prompt += contexts[i];
        prompt += "\n";
    }

    prompt += "\n[질문]\n";
    prompt += q;
    return prompt;
}

std::string sanitize_context_text(const std::string& text) {
    std::string out;
    out.reserve(text.size());
    for (size_t i = 0; i < text.size();) {
        const unsigned char c = static_cast<unsigned char>(text[i]);
        if (c == '\n' || c == '\r' || c == '\t') {
            out.push_back(' ');
            ++i;
            continue;
        }
        if (c < 0x20) {
            ++i;
            continue;
        }
        // Drop UTF-8 replacement character (EF BF BD), which usually means
        // the source text was decoded with the wrong encoding.
        if (i + 2 < text.size() &&
            static_cast<unsigned char>(text[i]) == 0xEF &&
            static_cast<unsigned char>(text[i + 1]) == 0xBF &&
            static_cast<unsigned char>(text[i + 2]) == 0xBD) {
            i += 3;
            continue;
        }
        out.push_back(text[i]);
        ++i;
    }
    return out;
}

// Return the largest position <= max_bytes that lies on a UTF-8 codepoint
// boundary. A boundary byte is one where the top two bits are NOT 10 (i.e.
// not a continuation byte). Backing off avoids cutting a multi-byte sequence
// in half.
size_t utf8_safe_cut(const std::string& s, size_t max_bytes) {
    if (max_bytes >= s.size()) return s.size();
    size_t pos = max_bytes;
    while (pos > 0 &&
           (static_cast<unsigned char>(s[pos]) & 0xC0) == 0x80) {
        --pos;
    }
    return pos;
}

// Strip leading continuation bytes left over from a mid-codepoint cut, drop
// invalid lead/continuation sequences, and stop before any incomplete trailing
// sequence. Output is guaranteed to be valid UTF-8.
std::string to_valid_utf8(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    size_t i = 0;
    while (i < s.size() &&
           (static_cast<unsigned char>(s[i]) & 0xC0) == 0x80) {
        ++i;
    }
    while (i < s.size()) {
        const unsigned char c = static_cast<unsigned char>(s[i]);
        size_t need;
        if (c < 0x80) {
            need = 1;
        } else if ((c & 0xE0) == 0xC0) {
            need = 2;
        } else if ((c & 0xF0) == 0xE0) {
            need = 3;
        } else if ((c & 0xF8) == 0xF0) {
            need = 4;
        } else {
            ++i;
            continue;
        }
        if (i + need > s.size()) {
            break;
        }
        bool ok = true;
        for (size_t k = 1; k < need; ++k) {
            if ((static_cast<unsigned char>(s[i + k]) & 0xC0) != 0x80) {
                ok = false;
                break;
            }
        }
        if (!ok) {
            ++i;
            continue;
        }
        out.append(s, i, need);
        i += need;
    }
    return out;
}

std::string truncate_chars(const std::string& text, size_t max_chars) {
    if (text.size() <= max_chars) {
        return text;
    }
    const size_t cut = utf8_safe_cut(text, max_chars);
    return text.substr(0, cut) + "\n...[truncated]";
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

std::string read_text_file(const std::filesystem::path& path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        return "";
    }
    return std::string(
        std::istreambuf_iterator<char>(in),
        std::istreambuf_iterator<char>());
}

int add_text_document(
    ai_rag::RAGEngine& engine,
    const std::filesystem::path& text_path) {
    const std::string text = read_text_file(text_path);
    if (trim(text).empty()) {
        std::cerr << "[chatbot_bridge] rag_init text file empty: "
                  << text_path << std::endl;
        return 0;
    }

    ai_rag::ChunkOptions options;
    options.max_chunk_size = 800;
    options.chunk_overlap = 120;
    options.split_by_page = false;
    options.split_by_paragraph = true;

    const auto chunks = ai_rag::TextChunker::chunk_text(
        text,
        text_path.string(),
        options);
    int loaded_docs = 0;
    for (const auto& chunk : chunks) {
        // The third-party chunker splits on byte boundaries, which can leave
        // a chunk starting or ending in the middle of a Korean (3-byte) UTF-8
        // codepoint. Re-validate before persisting — otherwise the JSON vector
        // store rejects the bare continuation byte (e.g. 0x96) with
        // type_error.316.
        const std::string sanitized = to_valid_utf8(chunk.text);
        if (trim(sanitized).empty()) {
            continue;
        }
        const std::string id =
            text_path.filename().string() + "#" + std::to_string(chunk.chunk_index);
        const std::string metadata =
            text_path.string() + "#chunk=" + std::to_string(chunk.chunk_index);
        if (engine.add_document(id, sanitized, metadata)) {
            ++loaded_docs;
        }
    }
    std::cerr << "[chatbot_bridge] rag_init load_text docs="
              << loaded_docs << ", text_path=" << text_path << std::endl;
    return loaded_docs;
}

std::optional<std::filesystem::path> find_text_fallback(const char* pdf_path) {
    const char* env_text = std::getenv("HMI_LAUNCHER_RAG_TEXT");
    if (env_text && std::strlen(env_text) > 0) {
        const std::filesystem::path p(env_text);
        if (std::filesystem::exists(p)) {
            return p;
        }
        std::cerr << "[chatbot_bridge] rag_init env text not found: "
                  << p << std::endl;
    }

    const std::filesystem::path pdf(pdf_path ? pdf_path : "");
    std::vector<std::filesystem::path> candidates;
    if (!pdf.empty()) {
        auto txt = pdf;
        txt.replace_extension(".txt");
        candidates.push_back(txt);
        candidates.push_back(pdf.string() + ".txt");
    }
    candidates.push_back("/tmp/models/rag/docs/NE1_2024_ko_KR.txt");

    for (const auto& candidate : candidates) {
        if (std::filesystem::exists(candidate)) {
            return candidate;
        }
    }
    return std::nullopt;
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
    const std::string raw_content = string_value(res.content);
    const std::string error_message = error_message_to_string(res.error_message);
    std::cerr << "[chatbot_bridge] generate result: "
              << "success=" << res.success
              << ", content_size=" << raw_content.size()
              << ", error_size=" << error_message.size()
              << ", tokens=" << res.tokens_used
              << ", generation_time_ms=" << res.generation_time_ms
              << ", ttft_ms=" << res.first_token_time_ms
              << std::endl;
    if (!raw_content.empty()) {
        std::cerr << "[chatbot_bridge] generate raw_content: ["
                  << raw_content.substr(0, 500) << "]" << std::endl;
    }
    if (!error_message.empty()) {
        std::cerr << "[chatbot_bridge] generate error: "
                  << error_message << std::endl;
    }
    const std::string out = res.success
        ? clean_response(raw_content)
        : error_message;
    if (res.success) {
        std::cerr << "[chatbot_bridge] generate cleaned_content: ["
                  << out.substr(0, 500) << "]" << std::endl;
    }
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
    const std::string raw_content = string_value(res.content);
    const std::string error_message = error_message_to_string(res.error_message);
    std::cerr << "[chatbot_bridge] rag_generate result: "
              << "success=" << res.success
              << ", content_size=" << raw_content.size()
              << ", error_size=" << error_message.size()
              << ", tokens=" << res.tokens_used
              << ", generation_time_ms=" << res.generation_time_ms
              << ", ttft_ms=" << res.first_token_time_ms
              << std::endl;
    if (!raw_content.empty()) {
        std::cerr << "[chatbot_bridge] rag_generate raw_content: ["
                  << raw_content.substr(0, 500) << "]" << std::endl;
    }
    if (!error_message.empty()) {
        std::cerr << "[chatbot_bridge] rag_generate error: "
                  << error_message << std::endl;
    }
    const std::string out = res.success
        ? clean_response(raw_content)
        : error_message;
    if (res.success) {
        std::cerr << "[chatbot_bridge] rag_generate cleaned_content: ["
                  << out.substr(0, 500) << "]" << std::endl;
    }
    return copy_string(out);
}

int chatbot_rag_init(
    ChatbotHandle* h,
    const char* embedding_model_path,
    const char* pdf_path,
    const char* index_path) {
    if (!h || !embedding_model_path || !pdf_path || !index_path) {
        std::cerr << "[chatbot_bridge] rag_init invalid input" << std::endl;
        return 0;
    }

    std::lock_guard<std::mutex> lock(h->rag_mutex);
    if (h->rag_ready) {
        return 1;
    }

    try {
        auto engine = std::make_unique<ai_rag::RAGEngine>();
        std::cerr << "[chatbot_bridge] rag_init embedding_model_path="
                  << embedding_model_path
                  << ", pdf_path=" << pdf_path
                  << ", index_path=" << index_path
                  << std::endl;

        if (!engine->load_embedding_model(embedding_model_path)) {
            std::cerr << "[chatbot_bridge] rag_init failed to load embedding model"
                      << std::endl;
            return 0;
        }

        const std::filesystem::path index(index_path);
        bool loaded_index = false;
        if (std::filesystem::exists(index)) {
            loaded_index = engine->load_index(index_path);
            std::cerr << "[chatbot_bridge] rag_init load_index="
                      << loaded_index << std::endl;
        }

        if (!loaded_index) {
            ai_rag::ChunkOptions options;
            options.max_chunk_size = 800;
            options.chunk_overlap = 120;
            options.split_by_page = false;
            options.split_by_paragraph = true;

            const int loaded_docs = engine->load_pdf(pdf_path, options);
            std::cerr << "[chatbot_bridge] rag_init load_pdf docs="
                      << loaded_docs << std::endl;
            int indexed_docs = loaded_docs;
            if (indexed_docs <= 0) {
                const auto text_fallback = find_text_fallback(pdf_path);
                if (text_fallback) {
                    indexed_docs = add_text_document(*engine, *text_fallback);
                } else {
                    std::cerr << "[chatbot_bridge] rag_init no text fallback found"
                              << std::endl;
                }
            }
            if (indexed_docs <= 0) {
                return 0;
            }

            const auto parent = index.parent_path();
            if (!parent.empty()) {
                std::filesystem::create_directories(parent);
            }
            if (!engine->save_index(index_path)) {
                std::cerr << "[chatbot_bridge] rag_init save_index failed"
                          << std::endl;
            }
        }

        h->rag = std::move(engine);
        h->rag_ready = true;
        std::cerr << "[chatbot_bridge] rag_init ready documents="
                  << h->rag->document_count() << std::endl;
        return 1;
    } catch (const std::exception& e) {
        std::cerr << "[chatbot_bridge] rag_init exception: " << e.what()
                  << std::endl;
        return 0;
    } catch (...) {
        std::cerr << "[chatbot_bridge] rag_init unknown exception" << std::endl;
        return 0;
    }
}

char* chatbot_generate_rag(ChatbotHandle* h, const char* prompt, int top_k) {
    if (!h || !h->provider || !prompt) return nullptr;

    std::vector<std::string> contexts;
    {
        std::lock_guard<std::mutex> lock(h->rag_mutex);
        if (h->rag_ready && h->rag) {
            try {
                const int safe_top_k = std::max(1, std::min(top_k, kRagMaxContexts));
                const auto results = h->rag->search(prompt, safe_top_k, "");
                std::cerr << "[chatbot_bridge] rag_search results="
                          << results.size() << std::endl;
                size_t context_chars = 0;
                for (const auto& result : results) {
                    if (!result.content.empty()) {
                        if (static_cast<int>(contexts.size()) >= kRagMaxContexts ||
                            context_chars >= kRagMaxContextChars) {
                            break;
                        }
                        const std::string sanitized = sanitize_context_text(result.content);
                        if (sanitized.empty()) {
                            continue;
                        }
                        const size_t remaining = kRagMaxContextChars - context_chars;
                        const size_t limit = std::min(kRagMaxSingleContextChars, remaining);
                        const std::string clipped = truncate_chars(sanitized, limit);
                        std::cerr << "[chatbot_bridge] rag_context score="
                                  << result.score
                                  << ", metadata=[" << result.metadata << "]"
                                  << ", clipped_size=" << clipped.size()
                                  << ", preview=["
                                  << clipped.substr(0, 180)
                                  << "]" << std::endl;
                        contexts.emplace_back(
                            "[source=" + result.metadata +
                            ", score=" + std::to_string(result.score) + "]\n" +
                            clipped);
                        context_chars += clipped.size();
                    }
                }
            } catch (const std::exception& e) {
                std::cerr << "[chatbot_bridge] rag_search exception: "
                          << e.what() << std::endl;
            } catch (...) {
                std::cerr << "[chatbot_bridge] rag_search unknown exception"
                          << std::endl;
            }
        }
    }

    ai_common::GenerateRequest req;
    const std::string rag_prompt = build_rag_user_prompt(prompt, contexts);
    req.user_prompt = build_gemma4_rag_prompt(rag_prompt.c_str());
    req.max_tokens = kRagMaxOutputTokens;
    req.temperature = 0.35f;
    req.top_p = 0.9f;
    req.top_k = 40;
    std::cerr << "[chatbot_bridge] rag_prompt size="
              << req.user_prompt.size()
              << ", contexts=" << contexts.size()
              << ", max_tokens=" << req.max_tokens
              << std::endl;

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
