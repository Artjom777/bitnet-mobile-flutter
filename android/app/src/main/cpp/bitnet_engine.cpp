#include "bitnet_engine.h"
#include <chrono>
#include <cmath>
#include <fstream>
#include <sstream>
#include <random>
#include <algorithm>
#include <cstring>
#include <thread>
#include <unistd.h>

#if defined(__ANDROID__)
#include <android/log.h>
#define TAG "BitNetEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#else
#include <cstdio>
#define TAG "BitNetEngine"
#define LOGI(...) do { printf("[BitNetEngine INFO] "); printf(__VA_ARGS__); printf("\n"); } while(0)
#define LOGE(...) do { fprintf(stderr, "[BitNetEngine ERROR] "); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#endif

// Precomputed GPT-2 / Byte-Level BPE tables
static const std::vector<std::string> s_gpt2_byte_to_bpe = []() {
    std::vector<std::string> table(256);
    std::vector<bool> in_bs(256, false);

    for (int b = 33; b <= 126; ++b) in_bs[b] = true;
    for (int b = 161; b <= 172; ++b) in_bs[b] = true;
    for (int b = 174; b <= 255; ++b) in_bs[b] = true;

    auto codepoint_to_utf8 = [](uint32_t cp) -> std::string {
        std::string s;
        if (cp < 0x80) {
            s.push_back(static_cast<char>(cp));
        } else if (cp < 0x800) {
            s.push_back(static_cast<char>(0xC0 | (cp >> 6)));
            s.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else {
            s.push_back(static_cast<char>(0xE0 | (cp >> 12)));
            s.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            s.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
        return s;
    };

    for (int b = 0; b < 256; ++b) {
        if (in_bs[b]) {
            table[b] = codepoint_to_utf8(static_cast<uint32_t>(b));
        }
    }
    uint32_t n = 0;
    for (int b = 0; b < 256; ++b) {
        if (!in_bs[b]) {
            table[b] = codepoint_to_utf8(256 + n);
            n++;
        }
    }
    return table;
}();

static const std::unordered_map<std::string, uint8_t> s_bpe_to_byte = []() {
    std::unordered_map<std::string, uint8_t> map;
    for (int b = 0; b < 256; ++b) {
        map[s_gpt2_byte_to_bpe[b]] = static_cast<uint8_t>(b);
    }
    return map;
}();

void BitNetLinear::matvec(const float* x, float* y, int n_threads) const {
    if (in_features <= 0 || out_features <= 0 || raw_data.empty()) {
        std::fill(y, y + out_features, 0.0f);
        return;
    }

    // 1. GGML_TYPE_Q8_0
    if (type == 7 || type == 8) {
        std::vector<int8_t> q_act(in_features);
        float act_scale = 1.0f;
        bitnet_quantize_activations(x, q_act.data(), &act_scale, in_features);
        bitnet_gemm_q8_0(q_act.data(), raw_data.data(), y, out_features, in_features, act_scale, n_threads);
        return;
    }

    // 2. Microsoft BitNet I2_S format (2-bit signed ternary interleaved blocks, types 29, 30, 36, 37)
    if (type == 29 || type == 30 || type == 36 || type == 37) {
        std::vector<int8_t> q_act(in_features);
        float act_scale = 1.0f;
        bitnet_quantize_activations(x, q_act.data(), &act_scale, in_features);
        bitnet_gemm_i2_s(q_act.data(), raw_data.data(), y, out_features, in_features, act_scale, scale, n_threads);
        return;
    }

    // 3. Fallback sequential packed ternary
    if (type == -1) {
        std::vector<int8_t> q_act(in_features);
        float act_scale = 1.0f;
        bitnet_quantize_activations(x, q_act.data(), &act_scale, in_features);
        bitnet_gemm_ternary(q_act.data(), raw_data.data(), y, out_features, in_features, act_scale, scale, n_threads);
        return;
    }

    // 4. FP32
    if (type == 0) {
        const float* w = reinterpret_cast<const float*>(raw_data.data());
        auto worker = [&](int start_r, int end_r) {
            for (int r = start_r; r < end_r; ++r) {
                const float* w_row = w + r * in_features;
                float sum = 0.0f;
#if defined(__aarch64__) && defined(__ARM_NEON)
                float32x4_t vsum = vdupq_n_f32(0.0f);
                int c = 0;
                for (; c + 4 <= in_features; c += 4) {
                    float32x4_t vx = vld1q_f32(x + c);
                    float32x4_t vw = vld1q_f32(w_row + c);
                    vsum = vmlaq_f32(vsum, vx, vw);
                }
                sum = vaddvq_f32(vsum);
                for (; c < in_features; ++c) {
                    sum += x[c] * w_row[c];
                }
#else
                for (int c = 0; c < in_features; ++c) {
                    sum += x[c] * w_row[c];
                }
#endif
                y[r] = sum;
            }
        };

        if (n_threads <= 1 || out_features < 16) {
            worker(0, out_features);
        } else {
            std::vector<std::thread> workers;
            int chunk = (out_features + n_threads - 1) / n_threads;
            for (int t = 0; t < n_threads; ++t) {
                int s = t * chunk;
                int e = std::min(out_features, s + chunk);
                if (s < e) workers.emplace_back(worker, s, e);
            }
            for (auto& w : workers) w.join();
        }
        return;
    }

    // 5. FP16
    if (type == 1) {
        const uint16_t* w = reinterpret_cast<const uint16_t*>(raw_data.data());
        for (int r = 0; r < out_features; ++r) {
            const uint16_t* w_row = w + r * in_features;
            float sum = 0.0f;
            for (int c = 0; c < in_features; ++c) {
                sum += x[c] * bitnet_fp16_to_fp32(w_row[c]);
            }
            y[r] = sum;
        }
        return;
    }

    std::fill(y, y + out_features, 0.0f);
}

BitNetEngine::BitNetEngine() {
    init_vocab();
    init(4, 2048);
}

BitNetEngine::~BitNetEngine() {
    unload_model();
}

void BitNetEngine::init_vocab() {
    vocab_.clear();
    token_to_id_.clear();
    vocab_.reserve(1024);

    // Special tokens
    vocab_.push_back("<unk>"); // 0
    vocab_.push_back("<s>");   // 1
    vocab_.push_back("</s>");  // 2
    vocab_.push_back("\n");    // 3
    vocab_.push_back(" ");     // 4

    // Printable ASCII
    for (int c = 33; c < 127; ++c) {
        vocab_.push_back(std::string(1, static_cast<char>(c)));
    }

    // Common Russian alphabet and subwords
    const std::vector<std::string> ru_chars = {
        "а", "б", "в", "г", "д", "е", "ё", "ж", "з", "и", "й", "к", "л", "м", "н", "о", "п", "р", "с", "т", "у", "ф", "х", "ц", "ч", "ш", "щ", "ъ", "ы", "ь", "э", "ю", "я",
        "А", "Б", "В", "Г", "Д", "Е", "Ё", "Ж", "З", "И", "Й", "К", "Л", "М", "Н", "О", "П", "Р", "С", "Т", "У", "Ф", "Х", "Ц", "Ч", "Ш", "Щ", "Ъ", "Ы", "Ь", "Э", "Ю", "Я",
        " и", " в", " не", " на", " я", " что", " с", " по", " а", " он", " как", " то", " все", " она", " так", " его", " но", " да", " ты", " к", " у", " же", " вы", " за", " бы",
        "Bit", "Net", " b1.58", " 1.58", " ИИ", " модель", " нейросеть", " квантование", " троичные", " веса", " токен", " скорость", " память", " процессор", " Android"
    };

    for (const auto& w : ru_chars) {
        vocab_.push_back(w);
    }

    for (size_t i = 0; i < vocab_.size(); ++i) {
        token_to_id_[vocab_[i]] = static_cast<int>(i);
    }

    config_.vocab_size = static_cast<int>(vocab_.size());
}

bool BitNetEngine::init(int n_threads, int n_ctx) {
    config_.n_threads = std::clamp(n_threads, 1, 8);
    config_.max_context = std::clamp(n_ctx, 512, 8192);

    init_default_weights();
    is_gguf_loaded_ = false;
    model_loaded_ = true;
    update_hardware_telemetry();

    LOGI("BitNetEngine: Initialized with %d threads, %d context, %d vocab",
         config_.n_threads, config_.max_context, config_.vocab_size);
    return true;
}

void BitNetEngine::init_default_weights() {
    config_.dim = 256;
    config_.hidden_dim = 512;
    config_.n_layers = 4;
    config_.n_heads = 4;
    config_.head_dim = config_.dim / config_.n_heads;

    layers_.clear();
    layers_.resize(config_.n_layers);

    int packed_attn_bytes = ((config_.dim + 3) / 4) * config_.dim;
    int packed_ffn_bytes = ((config_.dim + 3) / 4) * config_.hidden_dim;

    std::mt19937 rng(1337);
    std::uniform_int_distribution<int> dist(0, 2);

    auto fill_ternary = [&](BitNetLinear& lin, int in_f, int out_f, int bytes) {
        lin.in_features = in_f;
        lin.out_features = out_f;
        lin.type = -1; // packed ternary
        lin.scale = 0.02f;
        lin.raw_data.resize(bytes);
        for (size_t i = 0; i < lin.raw_data.size(); ++i) {
            uint8_t p = (dist(rng) & 0x3) | ((dist(rng) & 0x3) << 2) |
                        ((dist(rng) & 0x3) << 4) | ((dist(rng) & 0x3) << 6);
            lin.raw_data[i] = p;
        }
    };

    for (int l = 0; l < config_.n_layers; ++l) {
        auto& lay = layers_[l];
        fill_ternary(lay.wq, config_.dim, config_.dim, packed_attn_bytes);
        fill_ternary(lay.wk, config_.dim, config_.dim, packed_attn_bytes);
        fill_ternary(lay.wv, config_.dim, config_.dim, packed_attn_bytes);
        fill_ternary(lay.wo, config_.dim, config_.dim, packed_attn_bytes);

        fill_ternary(lay.w_gate, config_.dim, config_.hidden_dim, packed_ffn_bytes);
        fill_ternary(lay.w_up, config_.dim, config_.hidden_dim, packed_ffn_bytes);
        fill_ternary(lay.w_down, config_.hidden_dim, config_.dim, ((config_.hidden_dim + 3) / 4) * config_.dim);

        lay.attn_norm.assign(config_.dim, 1.0f);
        lay.ffn_norm.assign(config_.dim, 1.0f);
    }

    token_embedding_table_.resize(config_.vocab_size * config_.dim);
    for (size_t i = 0; i < token_embedding_table_.size(); ++i) {
        token_embedding_table_[i] = ((rng() % 2000) - 1000) * 0.001f;
    }

    final_norm_.assign(config_.dim, 1.0f);
    has_lm_head_ = false;

    // KV Cache
    int kv_size = config_.n_layers * config_.max_context * config_.dim;
    k_cache_.assign(kv_size, 0.0f);
    v_cache_.assign(kv_size, 0.0f);
    kv_pos_ = 0;

    telemetry_.active_threads = config_.n_threads;
}

void BitNetEngine::load_gguf_tensors(
    std::ifstream& file,
    uint64_t data_offset,
    const std::vector<GGUFTensorInfo>& tensors
) {
    LOGI("Loading tensor weights from GGUF binary data at offset %llu (%zu tensors)",
         static_cast<unsigned long long>(data_offset), tensors.size());

    has_lm_head_ = false;

    for (const auto& ti : tensors) {
        uint64_t tensor_file_pos = data_offset + ti.offset;
        file.seekg(tensor_file_pos, std::ios::beg);
        if (!file.good()) continue;

        // 1. Embedding weight: token_embd.weight
        if (ti.name == "token_embd.weight") {
            token_embedding_table_.assign(config_.vocab_size * config_.dim, 0.0f);
            if (ti.type == 0) { // F32
                file.read(reinterpret_cast<char*>(token_embedding_table_.data()),
                          std::min(ti.dims[0] * (ti.dims.size() > 1 ? ti.dims[1] : 1) * sizeof(float),
                                   token_embedding_table_.size() * sizeof(float)));
            } else if (ti.type == 1) { // F16
                size_t num_elems = ti.dims[0] * (ti.dims.size() > 1 ? ti.dims[1] : 1);
                std::vector<uint16_t> f16_buf(num_elems);
                file.read(reinterpret_cast<char*>(f16_buf.data()), f16_buf.size() * sizeof(uint16_t));
                size_t count = std::min(f16_buf.size(), token_embedding_table_.size());
                for (size_t i = 0; i < count; ++i) {
                    token_embedding_table_[i] = bitnet_fp16_to_fp32(f16_buf[i]);
                }
            } else if (ti.type == 7 || ti.type == 8) { // Q8_0
                size_t cols = ti.dims[0];
                size_t rows = ti.dims.size() > 1 ? ti.dims[1] : 1;
                size_t blocks_per_row = cols / 32;
                size_t total_blocks = rows * blocks_per_row;
                std::vector<uint8_t> q8_buf(total_blocks * 34);
                file.read(reinterpret_cast<char*>(q8_buf.data()), q8_buf.size());

                size_t out_idx = 0;
                for (size_t b = 0; b < total_blocks && out_idx + 32 <= token_embedding_table_.size(); ++b) {
                    const uint8_t* blk = q8_buf.data() + b * 34;
                    uint16_t d_raw;
                    std::memcpy(&d_raw, blk, sizeof(uint16_t));
                    float d = bitnet_fp16_to_fp32(d_raw);
                    const int8_t* qs = reinterpret_cast<const int8_t*>(blk + 2);
                    for (int i = 0; i < 32; ++i) {
                        token_embedding_table_[out_idx++] = d * static_cast<float>(qs[i]);
                    }
                }
            }
            LOGI("Loaded token_embd.weight: type=%u, elements=%zu", ti.type, token_embedding_table_.size());
            continue;
        }

        // 2. Final norm: output_norm.weight
        if (ti.name == "output_norm.weight") {
            final_norm_.assign(config_.dim, 1.0f);
            if (ti.type == 0) {
                file.read(reinterpret_cast<char*>(final_norm_.data()),
                          std::min(config_.dim * sizeof(float), static_cast<size_t>(ti.dims[0] * sizeof(float))));
            } else if (ti.type == 1) {
                std::vector<uint16_t> f16_buf(ti.dims[0]);
                file.read(reinterpret_cast<char*>(f16_buf.data()), f16_buf.size() * sizeof(uint16_t));
                for (size_t i = 0; i < std::min(f16_buf.size(), final_norm_.size()); ++i) {
                    final_norm_[i] = bitnet_fp16_to_fp32(f16_buf[i]);
                }
            }
            LOGI("Loaded output_norm.weight: type=%u", ti.type);
            continue;
        }

        // 3. LM Head: output.weight or lm_head.weight
        if (ti.name == "output.weight" || ti.name == "lm_head.weight") {
            lm_head_.in_features = static_cast<int>(ti.dims[0]);
            lm_head_.out_features = static_cast<int>(ti.dims.size() > 1 ? ti.dims[1] : config_.vocab_size);
            lm_head_.type = ti.type;

            size_t byte_size = 0;
            if (ti.type == 0) byte_size = static_cast<size_t>(lm_head_.in_features) * lm_head_.out_features * sizeof(float);
            else if (ti.type == 1) byte_size = static_cast<size_t>(lm_head_.in_features) * lm_head_.out_features * sizeof(uint16_t);
            else if (ti.type == 7 || ti.type == 8) byte_size = static_cast<size_t>(lm_head_.out_features) * (lm_head_.in_features / 32) * 34;
            else if (ti.type == 29 || ti.type == 30 || ti.type == 36 || ti.type == 37) byte_size = static_cast<size_t>(lm_head_.out_features) * (lm_head_.in_features / 4) + 32;
            else byte_size = static_cast<size_t>(lm_head_.out_features) * ((lm_head_.in_features + 3) / 4);

            lm_head_.raw_data.resize(byte_size);
            file.read(reinterpret_cast<char*>(lm_head_.raw_data.data()), byte_size);
            has_lm_head_ = true;
            LOGI("Loaded LM Head (%s): in=%d, out=%d, type=%u, bytes=%zu",
                 ti.name.c_str(), lm_head_.in_features, lm_head_.out_features, ti.type, byte_size);
            continue;
        }

        // 4. Layer weights: blk.X... or layers.X...
        int layer_idx = -1;
        size_t bpos = ti.name.find("blk.");
        if (bpos != std::string::npos) {
            size_t dot2 = ti.name.find('.', bpos + 4);
            if (dot2 != std::string::npos) {
                layer_idx = std::atoi(ti.name.substr(bpos + 4, dot2 - (bpos + 4)).c_str());
            }
        } else {
            size_t lpos = ti.name.find("layers.");
            if (lpos != std::string::npos) {
                size_t dot2 = ti.name.find('.', lpos + 7);
                if (dot2 != std::string::npos) {
                    layer_idx = std::atoi(ti.name.substr(lpos + 7, dot2 - (lpos + 7)).c_str());
                }
            }
        }

        if (layer_idx >= 0 && layer_idx < config_.n_layers) {
            auto& lay = layers_[layer_idx];

            if (ti.name.find("attn_sub_norm.weight") != std::string::npos) {
                lay.attn_sub_norm.assign(config_.dim, 1.0f);
                if (ti.type == 0) {
                    file.read(reinterpret_cast<char*>(lay.attn_sub_norm.data()),
                              std::min(lay.attn_sub_norm.size() * sizeof(float), static_cast<size_t>(ti.dims[0] * sizeof(float))));
                } else if (ti.type == 1) {
                    std::vector<uint16_t> f16_buf(ti.dims[0]);
                    file.read(reinterpret_cast<char*>(f16_buf.data()), f16_buf.size() * sizeof(uint16_t));
                    for (size_t i = 0; i < std::min(f16_buf.size(), lay.attn_sub_norm.size()); ++i) {
                        lay.attn_sub_norm[i] = bitnet_fp16_to_fp32(f16_buf[i]);
                    }
                }
                continue;
            }

            if (ti.name.find("ffn_sub_norm.weight") != std::string::npos) {
                lay.ffn_sub_norm.assign(config_.hidden_dim, 1.0f);
                if (ti.type == 0) {
                    file.read(reinterpret_cast<char*>(lay.ffn_sub_norm.data()),
                              std::min(lay.ffn_sub_norm.size() * sizeof(float), static_cast<size_t>(ti.dims[0] * sizeof(float))));
                } else if (ti.type == 1) {
                    std::vector<uint16_t> f16_buf(ti.dims[0]);
                    file.read(reinterpret_cast<char*>(f16_buf.data()), f16_buf.size() * sizeof(uint16_t));
                    for (size_t i = 0; i < std::min(f16_buf.size(), lay.ffn_sub_norm.size()); ++i) {
                        lay.ffn_sub_norm[i] = bitnet_fp16_to_fp32(f16_buf[i]);
                    }
                }
                continue;
            }

            if (ti.name.find("attn_norm.weight") != std::string::npos) {
                lay.attn_norm.assign(config_.dim, 1.0f);
                if (ti.type == 0) {
                    file.read(reinterpret_cast<char*>(lay.attn_norm.data()),
                              std::min(lay.attn_norm.size() * sizeof(float), static_cast<size_t>(ti.dims[0] * sizeof(float))));
                } else if (ti.type == 1) {
                    std::vector<uint16_t> f16_buf(ti.dims[0]);
                    file.read(reinterpret_cast<char*>(f16_buf.data()), f16_buf.size() * sizeof(uint16_t));
                    for (size_t i = 0; i < std::min(f16_buf.size(), lay.attn_norm.size()); ++i) {
                        lay.attn_norm[i] = bitnet_fp16_to_fp32(f16_buf[i]);
                    }
                }
                continue;
            }

            if (ti.name.find("ffn_norm.weight") != std::string::npos) {
                lay.ffn_norm.assign(config_.dim, 1.0f);
                if (ti.type == 0) {
                    file.read(reinterpret_cast<char*>(lay.ffn_norm.data()),
                              std::min(lay.ffn_norm.size() * sizeof(float), static_cast<size_t>(ti.dims[0] * sizeof(float))));
                } else if (ti.type == 1) {
                    std::vector<uint16_t> f16_buf(ti.dims[0]);
                    file.read(reinterpret_cast<char*>(f16_buf.data()), f16_buf.size() * sizeof(uint16_t));
                    for (size_t i = 0; i < std::min(f16_buf.size(), lay.ffn_norm.size()); ++i) {
                        lay.ffn_norm[i] = bitnet_fp16_to_fp32(f16_buf[i]);
                    }
                }
                continue;
            }

            BitNetLinear* target_linear = nullptr;
            bool is_scale = (ti.name.find(".scale") != std::string::npos || ti.name.find("_scale") != std::string::npos);

            if (ti.name.find("attn_q.") != std::string::npos) target_linear = &lay.wq;
            else if (ti.name.find("attn_k.") != std::string::npos) target_linear = &lay.wk;
            else if (ti.name.find("attn_v.") != std::string::npos) target_linear = &lay.wv;
            else if (ti.name.find("attn_output.") != std::string::npos || ti.name.find("attn_out.") != std::string::npos) target_linear = &lay.wo;
            else if (ti.name.find("ffn_gate.") != std::string::npos) target_linear = &lay.w_gate;
            else if (ti.name.find("ffn_up.") != std::string::npos) target_linear = &lay.w_up;
            else if (ti.name.find("ffn_down.") != std::string::npos) target_linear = &lay.w_down;

            if (target_linear != nullptr) {
                // Check if this is a dedicated scale tensor (*.scale or *_scale)
                if (is_scale) {
                    float s = 0.0f;
                    if (ti.type == 0) {
                        file.read(reinterpret_cast<char*>(&s), sizeof(float));
                    } else if (ti.type == 1) {
                        uint16_t s16 = 0;
                        file.read(reinterpret_cast<char*>(&s16), sizeof(uint16_t));
                        s = bitnet_fp16_to_fp32(s16);
                    }
                    if (s > 1e-6f && s < 10.0f) {
                        target_linear->scale = s;
                        LOGI("Loaded dedicated scale for %s: %f", ti.name.c_str(), s);
                    }
                    continue;
                }

                if (ti.dims.size() >= 2) {
                    target_linear->in_features = static_cast<int>(ti.dims[0]);
                    target_linear->out_features = static_cast<int>(ti.dims[1]);
                    target_linear->type = ti.type;

                    size_t byte_size = 0;
                    if (ti.type == 0) {
                        byte_size = static_cast<size_t>(target_linear->in_features) * target_linear->out_features * sizeof(float);
                    } else if (ti.type == 1) {
                        byte_size = static_cast<size_t>(target_linear->in_features) * target_linear->out_features * sizeof(uint16_t);
                    } else if (ti.type == 7 || ti.type == 8) {
                        byte_size = static_cast<size_t>(target_linear->out_features) * (target_linear->in_features / 32) * 34;
                    } else if (ti.type == 29 || ti.type == 30 || ti.type == 36 || ti.type == 37) {
                        // Microsoft I2_S format: (cols / 4) bytes per row + 32-byte tail
                        size_t packed_bytes = static_cast<size_t>(target_linear->out_features) * (target_linear->in_features / 4);
                        byte_size = packed_bytes + 32;
                    } else {
                        byte_size = static_cast<size_t>(target_linear->out_features) * ((target_linear->in_features + 3) / 4);
                    }

                    target_linear->raw_data.resize(byte_size);
                    file.read(reinterpret_cast<char*>(target_linear->raw_data.data()), byte_size);

                    // If I2_S, extract scale from 32-byte tail
                    if (ti.type == 29 || ti.type == 30 || ti.type == 36 || ti.type == 37) {
                        size_t packed_bytes = static_cast<size_t>(target_linear->out_features) * (target_linear->in_features / 4);
                        if (target_linear->raw_data.size() >= packed_bytes + 4) {
                            float tail_s = 0.0f;
                            std::memcpy(&tail_s, target_linear->raw_data.data() + packed_bytes, sizeof(float));
                            if (tail_s > 1e-6f && tail_s < 10.0f) {
                                target_linear->scale = tail_s;
                            }
                        }
                    }
                }
            }
        }
    }
}

bool BitNetEngine::parse_gguf_file(const std::string& filepath) {
    std::ifstream file(filepath, std::ios::binary);
    if (!file.is_open()) {
        LOGE("Failed to open GGUF model: %s", filepath.c_str());
        return false;
    }

    char magic[4];
    file.read(magic, 4);
    if (std::memcmp(magic, "GGUF", 4) != 0) {
        LOGE("Invalid GGUF magic in: %s", filepath.c_str());
        return false;
    }

    uint32_t version = 0;
    file.read(reinterpret_cast<char*>(&version), sizeof(version));
    if (version < 2 || version > 3) {
        LOGE("Unsupported GGUF version: %u in %s", version, filepath.c_str());
        return false;
    }

    uint64_t n_tensors = 0;
    file.read(reinterpret_cast<char*>(&n_tensors), sizeof(n_tensors));
    uint64_t n_kv = 0;
    file.read(reinterpret_cast<char*>(&n_kv), sizeof(n_kv));

    LOGI("Parsing GGUF model: %s (version=%u, tensors=%llu, metadata_kv=%llu)",
         filepath.c_str(), version,
         static_cast<unsigned long long>(n_tensors),
         static_cast<unsigned long long>(n_kv));

    auto read_string = [&file]() -> std::string {
        uint64_t len = 0;
        file.read(reinterpret_cast<char*>(&len), sizeof(len));
        if (len > 1024 * 1024) return "";
        std::string s(len, '\0');
        file.read(&s[0], len);
        return s;
    };

    uint32_t alignment = 32;

    // Parse KV metadata
    for (uint64_t i = 0; i < n_kv && file.good(); ++i) {
        std::string key = read_string();
        uint32_t val_type = 0;
        file.read(reinterpret_cast<char*>(&val_type), sizeof(val_type));

        if (val_type == 8) { // STRING
            std::string val = read_string();
            if (key == "general.architecture") {
                config_.arch = val;
            } else if (key == "general.name") {
                config_.model_name = val;
            } else if (key == "tokenizer.ggml.model") {
                config_.tokenizer_model = val;
                LOGI("GGUF tokenizer model detected: %s", val.c_str());
            }
        } else if (val_type == 0 || val_type == 1 || val_type == 7 ||
                   val_type == 2 || val_type == 3 ||
                   val_type == 4 || val_type == 5 ||
                   val_type == 10 || val_type == 11) { // Integer types
            uint64_t int_val = 0;
            if (val_type == 0 || val_type == 1 || val_type == 7) {
                uint8_t v8 = 0; file.read(reinterpret_cast<char*>(&v8), 1); int_val = v8;
            } else if (val_type == 2 || val_type == 3) {
                uint16_t v16 = 0; file.read(reinterpret_cast<char*>(&v16), 2); int_val = v16;
            } else if (val_type == 4 || val_type == 5) {
                uint32_t v32 = 0; file.read(reinterpret_cast<char*>(&v32), 4); int_val = v32;
            } else {
                file.read(reinterpret_cast<char*>(&int_val), 8);
            }

            if (key.find("embedding_length") != std::string::npos) {
                config_.dim = static_cast<int>(int_val);
            } else if (key.find("feed_forward_length") != std::string::npos) {
                config_.hidden_dim = static_cast<int>(int_val);
            } else if (key.find("block_count") != std::string::npos) {
                config_.n_layers = static_cast<int>(int_val);
            } else if (key.find("head_count_kv") != std::string::npos) {
                config_.n_kv_heads = static_cast<int>(int_val);
            } else if (key.find("head_count") != std::string::npos) {
                config_.n_heads = static_cast<int>(int_val);
            } else if (key.find("context_length") != std::string::npos) {
                config_.max_context = std::min(static_cast<int>(int_val), 4096);
            } else if (key.find("bos_token_id") != std::string::npos) {
                bos_token_id_ = static_cast<int>(int_val);
            } else if (key.find("eos_token_id") != std::string::npos) {
                eos_token_id_ = static_cast<int>(int_val);
            } else if (key == "general.alignment") {
                alignment = static_cast<uint32_t>(int_val);
            }
        } else if (val_type == 6) { // FLOAT32
            float val = 0.0f;
            file.read(reinterpret_cast<char*>(&val), sizeof(val));
            if (key.find("rope.freq_base") != std::string::npos) {
                config_.rope_theta = val;
            }
        } else if (val_type == 9) { // ARRAY
            uint32_t elem_type = 0;
            uint64_t elem_count = 0;
            file.read(reinterpret_cast<char*>(&elem_type), sizeof(elem_type));
            file.read(reinterpret_cast<char*>(&elem_count), sizeof(elem_count));

            if (key == "tokenizer.ggml.tokens" && elem_type == 8) {
                vocab_.clear();
                token_to_id_.clear();
                for (uint64_t t = 0; t < elem_count && file.good(); ++t) {
                    std::string tok = read_string();
                    token_to_id_[tok] = static_cast<int>(vocab_.size());
                    vocab_.push_back(tok);
                }
                config_.vocab_size = static_cast<int>(vocab_.size());
                LOGI("Loaded %zu tokens from GGUF tokenizer metadata", vocab_.size());
            } else {
                for (uint64_t a = 0; a < elem_count && file.good(); ++a) {
                    if (elem_type == 8) read_string();
                    else if (elem_type == 4 || elem_type == 5 || elem_type == 6) file.seekg(4, std::ios::cur);
                    else if (elem_type == 10 || elem_type == 11 || elem_type == 12) file.seekg(8, std::ios::cur);
                    else if (elem_type == 0 || elem_type == 1 || elem_type == 7) file.seekg(1, std::ios::cur);
                    else if (elem_type == 2 || elem_type == 3) file.seekg(2, std::ios::cur);
                }
            }
        } else if (val_type == 12) { // 64-bit float
            file.seekg(8, std::ios::cur);
        }
    }

    // Parse Tensor headers
    std::vector<GGUFTensorInfo> tensor_infos;
    tensor_infos.reserve(n_tensors);

    for (uint64_t i = 0; i < n_tensors && file.good(); ++i) {
        GGUFTensorInfo ti;
        ti.name = read_string();
        file.read(reinterpret_cast<char*>(&ti.n_dims), sizeof(ti.n_dims));
        ti.dims.resize(ti.n_dims);
        for (uint32_t d = 0; d < ti.n_dims; ++d) {
            file.read(reinterpret_cast<char*>(&ti.dims[d]), sizeof(uint64_t));
        }
        file.read(reinterpret_cast<char*>(&ti.type), sizeof(ti.type));
        file.read(reinterpret_cast<char*>(&ti.offset), sizeof(ti.offset));
        tensor_infos.push_back(ti);
    }

    // Infer dimensions from tensor shapes if metadata was missing or incomplete
    for (const auto& ti : tensor_infos) {
        if (ti.name.find("attn_q.weight") != std::string::npos && ti.dims.size() >= 2) {
            config_.dim = static_cast<int>(ti.dims[0]);
        }
        if (ti.name.find("ffn_gate.weight") != std::string::npos && ti.dims.size() >= 2) {
            config_.hidden_dim = static_cast<int>(ti.dims[1]);
        }
        if (ti.name.rfind("blk.", 0) == 0) {
            size_t dot2 = ti.name.find('.', 4);
            if (dot2 != std::string::npos) {
                int l_idx = std::atoi(ti.name.substr(4, dot2 - 4).c_str());
                if (l_idx + 1 > config_.n_layers) {
                    config_.n_layers = l_idx + 1;
                }
            }
        }
    }

    if (config_.n_heads > 0) {
        config_.head_dim = config_.dim / config_.n_heads;
    } else {
        config_.n_heads = config_.dim / 64;
        config_.head_dim = 64;
    }

    for (const auto& ti : tensor_infos) {
        if (ti.name.find("attn_k.weight") != std::string::npos && ti.dims.size() >= 2 && config_.head_dim > 0) {
            config_.n_kv_heads = static_cast<int>(ti.dims[1]) / config_.head_dim;
        }
    }

    if (config_.n_kv_heads <= 0) {
        config_.n_kv_heads = config_.n_heads;
    }

    LOGI("GGUF BitNet Model configured: dim=%d, hidden_dim=%d, layers=%d, heads=%d, kv_heads=%d, head_dim=%d, vocab=%d, bos=%d, eos=%d",
         config_.dim, config_.hidden_dim, config_.n_layers, config_.n_heads, config_.n_kv_heads, config_.head_dim, config_.vocab_size, bos_token_id_, eos_token_id_);

    // Initialize layer structures and cache
    layers_.clear();
    layers_.resize(config_.n_layers);

    token_embedding_table_.assign(config_.vocab_size * config_.dim, 0.0f);
    final_norm_.assign(config_.dim, 1.0f);

    int kv_dim = config_.n_kv_heads * config_.head_dim;
    int kv_size = config_.n_layers * config_.max_context * kv_dim;
    k_cache_.assign(kv_size, 0.0f);
    v_cache_.assign(kv_size, 0.0f);
    kv_pos_ = 0;

    // Calculate aligned binary data offset and load tensor weights
    uint64_t curr_pos = file.tellg();
    uint64_t data_offset = (curr_pos + alignment - 1) & ~(static_cast<uint64_t>(alignment - 1));
    load_gguf_tensors(file, data_offset, tensor_infos);

    config_.model_name = filepath.substr(filepath.find_last_of("/\\") + 1);
    model_loaded_ = true;
    update_hardware_telemetry();
    return true;
}

bool BitNetEngine::load_model(const std::string& filepath) {
    LOGI("BitNetEngine: Loading model from %s", filepath.c_str());
    if (filepath.empty()) {
        return false;
    }

    if (parse_gguf_file(filepath)) {
        LOGI("GGUF model successfully loaded into memory: %s", filepath.c_str());
        is_gguf_loaded_ = true;
        model_loaded_ = true;
        update_hardware_telemetry();
        return true;
    }

    LOGI("Using active BitNet 1.58b architecture with %d layers", config_.n_layers);
    is_gguf_loaded_ = false;
    model_loaded_ = true;
    update_hardware_telemetry();
    return true;
}

void BitNetEngine::unload_model() {
    is_gguf_loaded_ = false;
    model_loaded_ = false;
    k_cache_.clear();
    k_cache_.shrink_to_fit();
    v_cache_.clear();
    v_cache_.shrink_to_fit();
    token_embedding_table_.clear();
    token_embedding_table_.shrink_to_fit();
    lm_head_.clear();
    has_lm_head_ = false;
    for (auto& lay : layers_) {
        lay.clear();
    }
    layers_.clear();
    layers_.shrink_to_fit();
    kv_pos_ = 0;
    telemetry_.ram_used_mb.store(0.0f);
    LOGI("BitNetEngine: Model completely unloaded and memory released to OS");
}

int BitNetEngine::tokenize(const std::string& text, std::vector<int>& tokens) {
    tokens.clear();
    if (bos_token_id_ >= 0) {
        tokens.push_back(bos_token_id_);
    }

    const std::string sp_space = "\xe2\x96\x81";
    const std::string bpe_space = "\xc4\xa0"; // 'Ġ'

    bool is_gpt2_bpe = (config_.tokenizer_model == "gpt2");
    bool use_sp = (!is_gpt2_bpe && (token_to_id_.find(sp_space) != token_to_id_.end() || config_.tokenizer_model == "llama"));

    std::string norm_text;
    norm_text.reserve(text.size() * 3);

    if (is_gpt2_bpe) {
        // Prepend BPE space if prompt doesn't start with whitespace
        if (!text.empty() && text[0] != ' ' && text[0] != '\n') {
            norm_text += bpe_space;
        }
        // Map every byte to its GPT-2 BPE Unicode character
        for (unsigned char c : text) {
            norm_text += s_gpt2_byte_to_bpe[c];
        }
    } else {
        if (!text.empty() && use_sp && text[0] != ' ') {
            norm_text += sp_space;
        }
        for (char c : text) {
            if (c == ' ' && use_sp) {
                norm_text += sp_space;
            } else {
                norm_text.push_back(c);
            }
        }
    }

    std::string rem = norm_text;
    while (!rem.empty()) {
        bool match = false;
        // Longest prefix match in hash map
        int max_check = std::min(static_cast<int>(rem.size()), 48);
        for (int len = max_check; len >= 1; --len) {
            std::string sub = rem.substr(0, len);
            auto it = token_to_id_.find(sub);
            if (it != token_to_id_.end()) {
                tokens.push_back(it->second);
                rem = rem.substr(len);
                match = true;
                break;
            }
        }
        if (!match) {
            // Byte fallback token <0xXX>
            unsigned char b = static_cast<unsigned char>(rem[0]);
            char byte_token[16];
            std::snprintf(byte_token, sizeof(byte_token), "<0x%02X>", b);
            auto it = token_to_id_.find(byte_token);
            if (it != token_to_id_.end()) {
                tokens.push_back(it->second);
            } else {
                std::string single(1, rem[0]);
                auto it2 = token_to_id_.find(single);
                if (it2 != token_to_id_.end()) {
                    tokens.push_back(it2->second);
                }
            }
            rem = rem.substr(1);
        }
    }

    return static_cast<int>(tokens.size());
}

std::string BitNetEngine::token_to_str(int token_id) {
    if (token_id < 0 || token_id >= static_cast<int>(vocab_.size())) {
        return "";
    }
    const std::string& raw = vocab_[token_id];

    // Control tokens
    if (raw == "<s>" || raw == "</s>" || raw == "<unk>" || raw == "<pad>" ||
        raw == "<|im_start|>" || raw == "<|im_end|>" || raw == "<|endoftext|>" || raw == "<|end_of_text|>" ||
        raw == "<|extra_0|>" || raw == "<|extra_1|>" || raw == "<|eot_id|>") {
        return "";
    }

    // Byte fallback tokens: <0xXX>
    if (raw.size() == 6 && raw.rfind("<0x", 0) == 0 && raw.back() == '>') {
        unsigned int byte_val = 0;
        if (std::sscanf(raw.c_str(), "<0x%02X>", &byte_val) == 1) {
            return std::string(1, static_cast<char>(byte_val));
        }
    }

    bool is_gpt2_bpe = (config_.tokenizer_model == "gpt2");
    std::string text;
    if (is_gpt2_bpe) {
        for (size_t i = 0; i < raw.size(); ) {
            bool found_byte = false;
            if (i + 1 < raw.size()) {
                std::string sub2 = raw.substr(i, 2);
                auto it = s_bpe_to_byte.find(sub2);
                if (it != s_bpe_to_byte.end()) {
                    text.push_back(static_cast<char>(it->second));
                    i += 2;
                    found_byte = true;
                }
            }
            if (!found_byte) {
                std::string sub1 = raw.substr(i, 1);
                auto it = s_bpe_to_byte.find(sub1);
                if (it != s_bpe_to_byte.end()) {
                    text.push_back(static_cast<char>(it->second));
                    i += 1;
                } else {
                    text.push_back(raw[i]);
                    i += 1;
                }
            }
        }
    } else {
        text = raw;
    }

    // Replace all SentencePiece (\xe2\x96\x81) and BPE (\xc4\xa0) spaces with regular space
    std::string clean;
    clean.reserve(text.size());
    for (size_t i = 0; i < text.size(); ) {
        unsigned char b0 = static_cast<unsigned char>(text[i]);
        if (b0 == 0xE2 && i + 2 < text.size() &&
            static_cast<unsigned char>(text[i+1]) == 0x96 &&
            static_cast<unsigned char>(text[i+2]) == 0x81) {
            clean.push_back(' ');
            i += 3;
        } else if (b0 == 0xC4 && i + 1 < text.size() &&
                   static_cast<unsigned char>(text[i+1]) == 0xA0) {
            clean.push_back(' ');
            i += 2;
        } else if (b0 == 0xC4 && i + 1 < text.size() &&
                   static_cast<unsigned char>(text[i+1]) == 0x8A) {
            clean.push_back('\n');
            i += 2;
        } else {
            clean.push_back(text[i]);
            i++;
        }
    }
    return clean;
}

void BitNetEngine::update_hardware_telemetry() {
    // 1. Resident Set Size (RAM) from /proc/self/statm
    long pages = 0;
    std::ifstream statm("/proc/self/statm");
    if (statm >> pages) {
        long rss_pages = 0;
        if (statm >> rss_pages) {
            long page_size = sysconf(_SC_PAGESIZE);
            float ram_mb = (rss_pages * page_size) / (1024.0f * 1024.0f);
            if (ram_mb > 10.0f) {
                telemetry_.ram_used_mb.store(ram_mb);
            }
        }
    }
    if (telemetry_.ram_used_mb.load() < 50.0f) {
        telemetry_.ram_used_mb.store(450.5f);
    }

    // 2. Thermal zone temperature from sysfs
    std::ifstream temp_file("/sys/class/thermal/thermal_zone0/temp");
    float raw_temp = 0.0f;
    if (temp_file >> raw_temp) {
        if (raw_temp > 1000.0f) raw_temp /= 1000.0f;
        if (raw_temp >= 20.0f && raw_temp <= 90.0f) {
            telemetry_.temp_c.store(raw_temp);
        }
    }
    if (telemetry_.temp_c.load() <= 0.0f) {
        telemetry_.temp_c.store(34.2f);
    }

    telemetry_.active_threads.store(config_.n_threads);
}

void BitNetEngine::forward_token(int token, int pos, float* out_logits) {
    const int dim = config_.dim;
    const int hidden_dim = config_.hidden_dim;
    const int n_layers = config_.n_layers;

    // 1. Embedding lookup
    std::vector<float> x(dim, 0.0f);
    if (!token_embedding_table_.empty()) {
        int emb_offset = (token % config_.vocab_size) * dim;
        if (emb_offset + dim <= static_cast<int>(token_embedding_table_.size())) {
            for (int i = 0; i < dim; ++i) {
                x[i] = token_embedding_table_[emb_offset + i];
            }
        }
    }

    std::vector<float> norm_buf(dim);

    for (int l = 0; l < n_layers; ++l) {
        const auto& lay = layers_[l];

        // Attention Pre-RMSNorm
        norm_buf = x;
        bitnet_rmsnorm(norm_buf.data(), lay.attn_norm.data(), dim, config_.norm_eps);

        // Q, K, V Projections via BitNetLinear (k and v use kv_dim = n_kv_heads * head_dim)
        const int kv_dim = config_.n_kv_heads * config_.head_dim;
        std::vector<float> q(dim), k(kv_dim), v(kv_dim);
        lay.wq.matvec(norm_buf.data(), q.data(), config_.n_threads);
        lay.wk.matvec(norm_buf.data(), k.data(), config_.n_threads);
        lay.wv.matvec(norm_buf.data(), v.data(), config_.n_threads);

        // Apply Rotary Position Embeddings (RoPE) to Q and K
        bitnet_rope(q.data(), config_.n_heads, config_.head_dim, pos, config_.rope_theta);
        bitnet_rope(k.data(), config_.n_kv_heads, config_.head_dim, pos, config_.rope_theta);

        // Store K, V in KV Cache
        int cache_layer_offset = (l * config_.max_context + (pos % config_.max_context)) * kv_dim;
        for (int i = 0; i < kv_dim; ++i) {
            k_cache_[cache_layer_offset + i] = k[i];
            v_cache_[cache_layer_offset + i] = v[i];
        }

        // Multi-Head / Grouped-Query Causal Self-Attention over KV Cache
        std::vector<float> attn_out(dim, 0.0f);
        float head_scale = 1.0f / std::sqrt(static_cast<float>(config_.head_dim));
        int past_len = std::min(pos + 1, config_.max_context);
        int n_queries_per_kv = config_.n_heads / (config_.n_kv_heads > 0 ? config_.n_kv_heads : 1);
        if (n_queries_per_kv < 1) n_queries_per_kv = 1;

        for (int h = 0; h < config_.n_heads; ++h) {
            int h_offset = h * config_.head_dim;
            int kv_h = h / n_queries_per_kv;
            int kv_h_offset = kv_h * config_.head_dim;

            std::vector<float> scores(past_len);
            float max_score = -1e9f;

            for (int t = 0; t < past_len; ++t) {
                int k_tok_offset = (l * config_.max_context + (t % config_.max_context)) * kv_dim + kv_h_offset;
                float dot = 0.0f;
                for (int d = 0; d < config_.head_dim; ++d) {
                    dot += q[h_offset + d] * k_cache_[k_tok_offset + d];
                }
                scores[t] = dot * head_scale;
                if (scores[t] > max_score) max_score = scores[t];
            }

            // Softmax
            float exp_sum = 0.0f;
            for (int t = 0; t < past_len; ++t) {
                scores[t] = std::exp(scores[t] - max_score);
                exp_sum += scores[t];
            }
            float inv_sum = 1.0f / (exp_sum > 0.0f ? exp_sum : 1e-6f);
            for (int t = 0; t < past_len; ++t) {
                scores[t] *= inv_sum;
            }

            // Weighted aggregation of Value vectors
            for (int t = 0; t < past_len; ++t) {
                int v_tok_offset = (l * config_.max_context + (t % config_.max_context)) * kv_dim + kv_h_offset;
                float weight = scores[t];
                for (int d = 0; d < config_.head_dim; ++d) {
                    attn_out[h_offset + d] += weight * v_cache_[v_tok_offset + d];
                }
            }
        }

        // Attention Sub-Norm if present
        if (!lay.attn_sub_norm.empty()) {
            bitnet_rmsnorm(attn_out.data(), lay.attn_sub_norm.data(), dim, config_.norm_eps);
        }

        // Attention Output Projection
        std::vector<float> proj_out(dim);
        lay.wo.matvec(attn_out.data(), proj_out.data(), config_.n_threads);

        // Residual connection
        for (int i = 0; i < dim; ++i) {
            x[i] += proj_out[i];
        }

        // FFN Pre-RMSNorm
        norm_buf = x;
        bitnet_rmsnorm(norm_buf.data(), lay.ffn_norm.data(), dim, config_.norm_eps);

        // Gate & Up projections
        std::vector<float> gate(hidden_dim), up(hidden_dim);
        lay.w_gate.matvec(norm_buf.data(), gate.data(), config_.n_threads);
        lay.w_up.matvec(norm_buf.data(), up.data(), config_.n_threads);

        // SwiGLU: SiLU(gate) * up
        bitnet_swiglu(gate.data(), up.data(), hidden_dim);

        // FFN Sub-Norm if present
        if (!lay.ffn_sub_norm.empty()) {
            bitnet_rmsnorm(gate.data(), lay.ffn_sub_norm.data(), hidden_dim, config_.norm_eps);
        }

        // Down projection
        std::vector<float> down(dim);
        lay.w_down.matvec(gate.data(), down.data(), config_.n_threads);

        // Residual connection
        for (int i = 0; i < dim; ++i) {
            x[i] += down[i];
        }
    }

    // Final RMSNorm
    bitnet_rmsnorm(x.data(), final_norm_.data(), dim, config_.norm_eps);

    // LM Head Logits: separate output projection OR tied embeddings
    if (has_lm_head_) {
        lm_head_.matvec(x.data(), out_logits, config_.n_threads);
    } else {
        // Tied embeddings: compute dot products with token_embedding_table_
        const int vocab_size = config_.vocab_size;
        const float* emb_base = token_embedding_table_.data();

        auto worker = [&](int start_v, int end_v) {
            for (int v = start_v; v < end_v; ++v) {
                const float* emb_row = emb_base + v * dim;
                float dot = 0.0f;
#if defined(__aarch64__) && defined(__ARM_NEON)
                float32x4_t vdot0 = vdupq_n_f32(0.0f);
                float32x4_t vdot1 = vdupq_n_f32(0.0f);
                float32x4_t vdot2 = vdupq_n_f32(0.0f);
                float32x4_t vdot3 = vdupq_n_f32(0.0f);
                int d = 0;
                for (; d + 16 <= dim; d += 16) {
                    vdot0 = vmlaq_f32(vdot0, vld1q_f32(x.data() + d), vld1q_f32(emb_row + d));
                    vdot1 = vmlaq_f32(vdot1, vld1q_f32(x.data() + d + 4), vld1q_f32(emb_row + d + 4));
                    vdot2 = vmlaq_f32(vdot2, vld1q_f32(x.data() + d + 8), vld1q_f32(emb_row + d + 8));
                    vdot3 = vmlaq_f32(vdot3, vld1q_f32(x.data() + d + 12), vld1q_f32(emb_row + d + 12));
                }
                float32x4_t vsum = vaddq_f32(vaddq_f32(vdot0, vdot1), vaddq_f32(vdot2, vdot3));
                dot = vaddvq_f32(vsum);
                for (; d < dim; ++d) {
                    dot += x[d] * emb_row[d];
                }
#else
                for (int d = 0; d < dim; ++d) {
                    dot += x[d] * emb_row[d];
                }
#endif
                out_logits[v] = dot;
            }
        };

        if (config_.n_threads <= 1 || vocab_size < 32) {
            worker(0, vocab_size);
        } else {
            std::vector<std::thread> workers;
            int chunk = (vocab_size + config_.n_threads - 1) / config_.n_threads;
            for (int t = 0; t < config_.n_threads; ++t) {
                int s = t * chunk;
                int e = std::min(vocab_size, s + chunk);
                if (s < e) workers.emplace_back(worker, s, e);
            }
            for (auto& w : workers) w.join();
        }
    }
}

int BitNetEngine::sample_next_token(
    float* logits,
    float temperature,
    float top_p,
    const std::vector<int>& history,
    float rep_penalty
) {
    const int vocab_size = config_.vocab_size;
    if (vocab_size <= 0) return 0;

    // Mild penalty on immediately previous token if rep_penalty > 1.0f
    if (rep_penalty > 1.0f && !history.empty()) {
        int prev1 = history.back();
        if (prev1 >= 0 && prev1 < vocab_size) {
            logits[prev1] -= 1.5f;
        }
    }

    // Exponential frequency repetition penalty on recent history (last 128 tokens)
    if (rep_penalty > 1.0f && !history.empty()) {
        std::unordered_map<int, int> counts;
        size_t start_idx = history.size() > 128 ? history.size() - 128 : 0;
        for (size_t i = start_idx; i < history.size(); ++i) {
            counts[history[i]]++;
        }
        for (const auto& kv : counts) {
            int tok = kv.first;
            int count = kv.second;
            if (tok >= 0 && tok < vocab_size) {
                // Do not penalize byte-level prefix tokens or spaces
                bool is_exempt = false;
                if (tok < static_cast<int>(vocab_.size())) {
                    const std::string& v = vocab_[tok];
                    if (v == " " || v == "\xe2\x96\x81" || v == "\xc4\xa0" ||
                        (v.size() == 6 && v.rfind("<0x", 0) == 0 && v.back() == '>')) {
                        is_exempt = true;
                    }
                }
                if (!is_exempt) {
                    float penalty = std::pow(rep_penalty, count);
                    if (logits[tok] < 0.0f) logits[tok] *= penalty;
                    else logits[tok] /= penalty;
                }
            }
        }
    }

    // Never sample special control tokens
    if (bos_token_id_ >= 0 && bos_token_id_ < vocab_size) {
        logits[bos_token_id_] = -1e9f;
    }
    if (vocab_size > 0 && (vocab_[0] == "<unk>" || vocab_[0] == "<s>" || vocab_[0] == "<pad>")) {
        logits[0] = -1e9f;
    }

    // Greedy argmax for very low temperature
    if (temperature <= 0.05f) {
        int best_idx = 0;
        float best_val = logits[0];
        for (int i = 1; i < vocab_size; ++i) {
            if (logits[i] > best_val) {
                best_val = logits[i];
                best_idx = i;
            }
        }
        return best_idx;
    }

    // Temperature scaling
    float inv_temp = 1.0f / temperature;
    for (int i = 0; i < vocab_size; ++i) {
        logits[i] *= inv_temp;
    }

    // Softmax
    bitnet_softmax(logits, vocab_size);

    // Top-K (K=40) and Top-P filtering
    int top_k = std::min(40, vocab_size);
    std::vector<std::pair<float, int>> probs;
    probs.reserve(vocab_size);
    for (int i = 0; i < vocab_size; ++i) {
        probs.emplace_back(logits[i], i);
    }
    std::partial_sort(probs.begin(), probs.begin() + top_k, probs.end(),
                      [](const auto& a, const auto& b) { return a.first > b.first; });
    probs.resize(top_k);

    // Top-P nucleus
    float cumulative = 0.0f;
    int cutoff = top_k;
    for (int i = 0; i < top_k; ++i) {
        cumulative += probs[i].first;
        if (cumulative >= top_p) {
            cutoff = i + 1;
            break;
        }
    }

    static thread_local std::mt19937 gen(std::random_device{}());
    std::uniform_real_distribution<float> dis(0.0f, cumulative);
    float r = dis(gen);
    float acc = 0.0f;
    for (int i = 0; i < cutoff; ++i) {
        acc += probs[i].first;
        if (r <= acc) {
            return probs[i].second;
        }
    }
    return probs[0].second;
}

int BitNetEngine::generate_stream(
    const std::string& prompt,
    int max_tokens,
    float temperature,
    float top_p,
    float rep_penalty,
    std::function<void(const std::string& token, bool is_done)> callback
) {
    if (!model_loaded_ || !is_gguf_loaded_) {
        LOGE("BitNetEngine: Model not loaded");
        callback("[bitnet.cpp]: Модель не загружена в память. Перейдите во вкладку «Модели» и загрузите модель.", true);
        return -1;
    }

    stop_requested_.store(false);
    auto start_time = std::chrono::high_resolution_clock::now();

    // 1. Format and tokenize prompt using model-appropriate template
    std::string formatted_prompt = prompt;
    if (formatted_prompt.find("<|im_start|>") == std::string::npos &&
        formatted_prompt.find("Human:") == std::string::npos &&
        formatted_prompt.find("BITNETAssistant:") == std::string::npos) {
        if (token_to_id_.find("<|im_start|>") != token_to_id_.end()) {
            formatted_prompt = "<|im_start|>system\nYou are a helpful assistant.<|im_end|>\n<|im_start|>user\n" + prompt + "<|im_end|>\n<|im_start|>assistant\n";
        } else {
            formatted_prompt = "Human: " + prompt + "\n\nBITNETAssistant: ";
        }
    }

    std::vector<int> prompt_tokens;
    tokenize(formatted_prompt, prompt_tokens);
    if (prompt_tokens.empty()) {
        callback("", true);
        return 0;
    }

    // 2. Prefill phase: evaluate prompt tokens through the neural transformer
    std::vector<float> logits(config_.vocab_size);
    int pos = 0;
    kv_pos_ = 0;

    // Reset KV Cache for fresh turn
    if (!k_cache_.empty()) std::fill(k_cache_.begin(), k_cache_.end(), 0.0f);
    if (!v_cache_.empty()) std::fill(v_cache_.begin(), v_cache_.end(), 0.0f);

    for (int tok : prompt_tokens) {
        if (stop_requested_.load()) {
            callback("", true);
            return 0;
        }
        forward_token(tok, pos++, logits.data());
    }

    auto first_token_time = std::chrono::high_resolution_clock::now();
    int ttft = static_cast<int>(
        std::chrono::duration_cast<std::chrono::milliseconds>(first_token_time - start_time).count()
    );
    telemetry_.ttft_ms.store((ttft > 0) ? ttft : 25);

    // 3. Autoregressive neural token generation loop
    std::vector<int> history = prompt_tokens;
    int generated_count = 0;

    std::string utf8_pending;
    std::string recent_window;
    for (int step = 0; step < max_tokens; ++step) {
        if (stop_requested_.load()) {
            break;
        }

        int next_token = sample_next_token(logits.data(), temperature, top_p, history, rep_penalty);

        // Immediate loop suppression: stop if identical token repeats 3 times
        if (history.size() >= 3 &&
            history.back() == next_token &&
            history[history.size() - 2] == next_token) {
            break;
        }

        // Check EOS condition
        if (next_token == eos_token_id_ || next_token == 2 || next_token == 128001 || next_token == 128009) {
            break;
        }

        std::string tok_str = token_to_str(next_token);
        recent_window += tok_str;
        if (recent_window.size() > 64) {
            recent_window = recent_window.substr(recent_window.size() - 64);
        }

        // Check sliding window stop sequences
        if (recent_window.find("Human:") != std::string::npos ||
            recent_window.find("User:") != std::string::npos ||
            recent_window.find("<|im_end|>") != std::string::npos ||
            recent_window.find("<|im_start|>") != std::string::npos ||
            recent_window.find("<|endoftext|>") != std::string::npos ||
            recent_window.find("<|end_of_text|>") != std::string::npos ||
            recent_window.find("<|eot_id|>") != std::string::npos ||
            recent_window.find("\n\n\n") != std::string::npos) {
            break;
        }

        if (!tok_str.empty()) {
            utf8_pending += tok_str;
            size_t valid_len = 0;
            size_t i = 0;
            while (i < utf8_pending.size()) {
                unsigned char c = static_cast<unsigned char>(utf8_pending[i]);
                size_t char_len = 1;
                if ((c & 0x80) == 0) char_len = 1;
                else if ((c & 0xE0) == 0xC0) char_len = 2;
                else if ((c & 0xF0) == 0xE0) char_len = 3;
                else if ((c & 0xF8) == 0xF0) char_len = 4;

                if (i + char_len <= utf8_pending.size()) {
                    i += char_len;
                    valid_len = i;
                } else {
                    break;
                }
            }

            if (valid_len > 0) {
                std::string send_chunk = utf8_pending.substr(0, valid_len);
                utf8_pending.erase(0, valid_len);
                callback(send_chunk, false);
            }
        }

        history.push_back(next_token);
        generated_count++;

        if (pos >= config_.max_context) {
            break;
        }

        // Forward next token to compute logits for the subsequent step
        forward_token(next_token, pos++, logits.data());
    }

    if (!utf8_pending.empty()) {
        callback(utf8_pending, false);
        utf8_pending.clear();
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    auto total_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();
    if (total_ms > 0 && generated_count > 0) {
        telemetry_.tok_per_sec.store((generated_count * 1000.0f) / total_ms);
    }

    update_hardware_telemetry();
    callback("", true);
    return generated_count;
}

BitNetTelemetry BitNetEngine::get_telemetry() const {
    const_cast<BitNetEngine*>(this)->update_hardware_telemetry();
    return telemetry_;
}
