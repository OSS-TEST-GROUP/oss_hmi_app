#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ChatbotHandle ChatbotHandle;

/**
 * Create a chatbot instance from a JSON config path.
 * Returns nullptr on failure.
 */
ChatbotHandle* chatbot_create(const char* config_path);

/**
 * Generate a response for a prompt.
 * The returned string must be released with chatbot_free_string().
 * Returns nullptr on failure.
 */
char* chatbot_generate(ChatbotHandle* handle, const char* prompt);

/**
 * Returns 1 when the underlying provider supports audio multimodal generation.
 */
int chatbot_has_audio(ChatbotHandle* handle);

/**
 * Generate a response from a prompt plus PCM float audio.
 * The returned string must be released with chatbot_free_string().
 * Returns nullptr on failure.
 */
char* chatbot_generate_audio_f32(
    ChatbotHandle* handle,
    const char* prompt,
    const float* pcm,
    int sample_count,
    int sample_rate,
    int channels);

/**
 * Generate a response with caller-provided context strings.
 * The returned string must be released with chatbot_free_string().
 * Returns nullptr on failure.
 */
char* chatbot_generate_with_contexts(
    ChatbotHandle* handle,
    const char* prompt,
    const char** contexts,
    int context_count);

/**
 * Initialize the RAG index used by chatbot_generate_rag().
 * Returns 1 on success, 0 on failure.
 */
int chatbot_rag_init(
    ChatbotHandle* handle,
    const char* embedding_model_path,
    const char* pdf_path,
    const char* index_path);

/**
 * Generate a response after retrieving vehicle-guide contexts through RAG.
 * Falls back to normal generation when RAG is not initialized or returns no
 * contexts. The returned string must be released with chatbot_free_string().
 */
char* chatbot_generate_rag(ChatbotHandle* handle, const char* prompt, int top_k);

/**
 * Free a string returned by chatbot_generate().
 */
void chatbot_free_string(char* str);

/**
 * Destroy a chatbot instance.
 */
void chatbot_destroy(ChatbotHandle* handle);

#ifdef __cplusplus
}
#endif
