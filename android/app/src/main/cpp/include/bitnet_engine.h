#ifndef BITNET_ENGINE_H
#define BITNET_ENGINE_H

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include "bitnet_kernel.h"

struct BitNetConfig {
    int dim = 2048;
    int hidden_dim = 5632;
    int n_layers = 16;
    int n_heads = 16;
    int head_dim = 128;
    int vocab_size = 32000;
    int max_context = 4096;
    int n_threads = 4;
    float norm_eps = 1e-5f;
    std::string model_name = "BitNet-b1.58-2B-4T";
    std::string arch = "BitNet 1.58b Ternary";
};

struct BitNetTelemetry {
    float tok_per_sec = 0.0f;
    int ttft_ms = 0;
    float ram_used_mb = 0.0f;
    int active_threads = 4;
    float temp_c = 34.2f;
};

class BitNetEngine {
public:
    BitNetEngine();
    ~BitNetEngine();

    bool init(int n_threads, int n_ctx);
    bool load_model(const std::string& filepath);
    void unload_model();
    bool is_loaded() const { return model_loaded_; }

    int tokenize(const std::string& text, std::vector<int>& tokens);
    std::string token_to_str(int token_id);

    int generate_stream(
        const std::string& prompt,
        int max_tokens,
        float temperature,
        float top_p,
        float rep_penalty,
        std::function<void(const std::string& token, bool is_done)> callback
    );

    BitNetTelemetry get_telemetry() const;
    const BitNetConfig& get_config() const { return config_; }

private:
    BitNetConfig config_;
    bool model_loaded_ = false;
    mutable BitNetTelemetry telemetry_;

    struct Layer {
        std::vector<uint8_t> wq_packed;
        std::vector<uint8_t> wk_packed;
        std::vector<uint8_t> wv_packed;
        std::vector<uint8_t> wo_packed;

        std::vector<uint8_t> w_gate_packed;
        std::vector<uint8_t> w_up_packed;
        std::vector<uint8_t> w_down_packed;

        std::vector<float> attn_norm;
        std::vector<float> ffn_norm;
    };

    std::vector<Layer> layers_;
    std::vector<float> token_embedding_table_;
    std::vector<float> final_norm_;
    std::vector<uint8_t> lm_head_packed_;
    std::vector<std::string> vocab_;

    // KV Cache
    std::vector<float> k_cache_;
    std::vector<float> v_cache_;
    int kv_pos_ = 0;

    int sample_next_token(
        float* logits,
        float temperature,
        float top_p,
        const std::vector<int>& history,
        float rep_penalty
    );

    void forward_token(int token, int pos, float* out_logits);
    void init_vocab();
    void init_default_weights();
    bool parse_gguf_file(const std::string& filepath);
};

#endif // BITNET_ENGINE_H
