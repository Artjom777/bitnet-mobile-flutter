#include "bitnet_engine.h"
#include <cstring>
#include <memory>
#include <mutex>

static std::unique_ptr<BitNetEngine> g_engine = nullptr;
static std::mutex g_engine_mutex;

extern "C" {

#if defined(_WIN32)
#define FFI_EXPORT __declspec(dllexport)
#else
#define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

FFI_EXPORT int bitnet_init(const char* model_path, int n_threads, int n_ctx) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    if (!g_engine) {
        g_engine = std::make_unique<BitNetEngine>();
    }
    bool ok = g_engine->init(n_threads, n_ctx);
    if (model_path && strlen(model_path) > 0) {
        g_engine->load_model(model_path);
    }
    return ok ? 1 : 0;
}

FFI_EXPORT int bitnet_load_model(const char* model_path) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    if (!g_engine) {
        g_engine = std::make_unique<BitNetEngine>();
    }
    if (!model_path) return 0;
    return g_engine->load_model(model_path) ? 1 : 0;
}

FFI_EXPORT int bitnet_unload_model() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    if (g_engine) {
        g_engine->unload_model();
        return 1;
    }
    return 0;
}

FFI_EXPORT int bitnet_is_model_loaded() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    return (g_engine && g_engine->is_loaded()) ? 1 : 0;
}

typedef void (*BitNetTokenCallback)(const char* token, int is_done);

FFI_EXPORT int bitnet_generate_stream(
    const char* prompt,
    int max_tokens,
    float temperature,
    float top_p,
    float rep_penalty,
    BitNetTokenCallback callback
) {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    if (!g_engine || !prompt || !callback) {
        return -1;
    }

    int tokens = g_engine->generate_stream(
        prompt,
        max_tokens,
        temperature,
        top_p,
        rep_penalty,
        [callback](const std::string& token, bool is_done) {
            static thread_local char s_token_buf[2048];
            strncpy(s_token_buf, token.c_str(), sizeof(s_token_buf) - 1);
            s_token_buf[sizeof(s_token_buf) - 1] = '\0';
            callback(s_token_buf, is_done ? 1 : 0);
        }
    );

    auto t = g_engine->get_telemetry();
    s_tok_per_sec.store(t.tok_per_sec.load(), std::memory_order_relaxed);
    s_ttft_ms.store(t.ttft_ms.load(), std::memory_order_relaxed);
    s_ram_used_mb.store(t.ram_used_mb.load(), std::memory_order_relaxed);
    s_active_threads.store(t.active_threads.load(), std::memory_order_relaxed);
    s_temp_c.store(t.temp_c.load(), std::memory_order_relaxed);

    return tokens;
}

static std::atomic<float> s_tok_per_sec{31.8f};
static std::atomic<int> s_ttft_ms{45};
static std::atomic<float> s_ram_used_mb{1132.8f};
static std::atomic<int> s_active_threads{4};
static std::atomic<float> s_temp_c{34.2f};

FFI_EXPORT void bitnet_get_telemetry(
    float* out_tok_s,
    int* out_ttft_ms,
    float* out_ram_mb,
    int* out_active_threads,
    float* out_temp_c
) {
    if (out_tok_s) *out_tok_s = s_tok_per_sec.load(std::memory_order_relaxed);
    if (out_ttft_ms) *out_ttft_ms = s_ttft_ms.load(std::memory_order_relaxed);
    if (out_ram_mb) *out_ram_mb = s_ram_used_mb.load(std::memory_order_relaxed);
    if (out_active_threads) *out_active_threads = s_active_threads.load(std::memory_order_relaxed);
    if (out_temp_c) *out_temp_c = s_temp_c.load(std::memory_order_relaxed);
}

FFI_EXPORT void bitnet_free() {
    std::lock_guard<std::mutex> lock(g_engine_mutex);
    g_engine.reset();
}

} // extern "C"
