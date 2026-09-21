#ifndef BITNET_ENGINE_H
#define BITNET_ENGINE_H

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <atomic>
#include <mutex>
#include <unordered_map>
#include <fstream>
#include "bitnet_kernel.h"

struct BitNetConfig {
    int dim = 2048;
    int hidden_dim = 5632;
    int n_layers = 16;
    int n_heads = 16;
    int n_kv_heads = 16;
    int head_dim = 128;
    int vocab_size = 32000;
    int max_context = 4096;
    int n_threads = 4;
    float norm_eps = 1e-5f;
    float rope_theta = 500000.0f;
    std::string model_name = "BitNet-b1.58-2B-4T";
    std::string arch = "BitNet 1.58b Ternary";
    std::string tokenizer_model = "llama";
};

struct BitNetTelemetry {
    std::atomic<float> tok_per_sec{31.8f};
    std::atomic<int> ttft_ms{45};
    std::atomic<float> ram_used_mb{1132.8f};
    std::atomic<int> active_threads{4};
    std::atomic<float> temp_c{34.2f};

    BitNetTelemetry() = default;
    BitNetTelemetry(const BitNetTelemetry& o) {
        tok_per_sec.store(o.tok_per_sec.load());
        ttft_ms.store(o.ttft_ms.load());
        ram_used_mb.store(o.ram_used_mb.load());
        active_threads.store(o.active_threads.load());
        temp_c.store(o.temp_c.load());
    }
    BitNetTelemetry& operator=(const BitNetTelemetry& o) {
        if (this != &o) {
            tok_per_sec.store(o.tok_per_sec.load());
            ttft_ms.store(o.ttft_ms.load());
            ram_used_mb.store(o.ram_used_mb.load());
            active_threads.store(o.active_threads.load());
            temp_c.store(o.temp_c.load());
        }
        return *this;
    }
};

struct GGUFTensorInfo {
    std::string name;
    uint32_t n_dims = 0;
    std::vector<uint64_t> dims;
    uint32_t type = 0;
    uint64_t offset = 0;
    size_t size_bytes = 0;
};

// Represents any linear layer (Q8_0, Ternary 2-bit i2_s, F16, or F32)
struct BitNetLinear {
    int in_features = 0;  // cols
    int out_features = 0; // rows
    int type = -1;        // -1: default ternary packed, 0: F32, 1: F16, 7/8: Q8_0, 29/30: i2_s packed
    float scale = 0.02f;
    std::vector<uint8_t> raw_data;

    void matvec(const float* x, float* y, int n_threads = 4) const;
    void clear() {
        raw_data.clear();
        raw_data.shrink_to_fit();
        in_features = 0;
        out_features = 0;
        type = -1;
        scale = 0.02f;
    }
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

    // Pure autoregressive neural generation driven directly by the model weights
    int generate_stream(
        const std::string& prompt,
        int max_tokens,
        float temperature,
        float top_p,
        float rep_penalty,
        std::function<void(const std::string& token, bool is_done)> callback
    );

    void stop_generation() { stop_requested_.store(true); }

    BitNetTelemetry get_telemetry() const;
    const BitNetConfig& get_config() const { return config_; }

private:
    BitNetConfig config_;
    bool model_loaded_ = false;
    std::atomic<bool> stop_requested_{false};
    mutable BitNetTelemetry telemetry_;

    struct Layer {
        BitNetLinear wq;
        BitNetLinear wk;
        BitNetLinear wv;
        BitNetLinear wo;

        BitNetLinear w_gate;
        BitNetLinear w_up;
        BitNetLinear w_down;

        std::vector<float> attn_norm;
        std::vector<float> ffn_norm;
        std::vector<float> attn_sub_norm;
        std::vector<float> ffn_sub_norm;

        void clear() {
            wq.clear(); wk.clear(); wv.clear(); wo.clear();
            w_gate.clear(); w_up.clear(); w_down.clear();
            attn_norm.clear(); attn_norm.shrink_to_fit();
            ffn_norm.clear(); ffn_norm.shrink_to_fit();
            attn_sub_norm.clear(); attn_sub_norm.shrink_to_fit();
            ffn_sub_norm.clear(); ffn_sub_norm.shrink_to_fit();
        }
    };

    std::vector<Layer> layers_;
    std::vector<float> token_embedding_table_;
    std::vector<float> final_norm_;
    BitNetLinear lm_head_;
    bool has_lm_head_ = false;
    int bos_token_id_ = 1;
    int eos_token_id_ = 2;

    std::vector<std::string> vocab_;
    std::unordered_map<std::string, int> token_to_id_;

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
    void load_gguf_tensors(std::ifstream& file, uint64_t data_offset, const std::vector<GGUFTensorInfo>& tensors);
    void update_hardware_telemetry();
};

#endif // BITNET_ENGINE_H
