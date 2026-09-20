#include "bitnet_kernel.h"
#include <cmath>
#include <cstring>
#include <algorithm>
#include <vector>
#include <thread>

void bitnet_quantize_activations(const float* input, int8_t* output, float* scale, int n) {
    float amax = 1e-6f;
#if defined(__aarch64__) && defined(__ARM_NEON)
    float32x4_t vmax = vdupq_n_f32(0.0f);
    int i = 0;
    for (; i + 4 <= n; i += 4) {
        float32x4_t v = vld1q_f32(input + i);
        vmax = vmaxq_f32(vmax, vabsq_f32(v));
    }
    amax = std::max(amax, vmaxvq_f32(vmax));
    for (; i < n; ++i) {
        amax = std::max(amax, std::abs(input[i]));
    }
#else
    for (int i = 0; i < n; ++i) {
        amax = std::max(amax, std::abs(input[i]));
    }
#endif

    float s = 127.0f / amax;
    *scale = amax / 127.0f;

    for (int i = 0; i < n; ++i) {
        float val = input[i] * s;
        val = std::clamp(val, -127.0f, 127.0f);
        output[i] = static_cast<int8_t>(std::round(val));
    }
}

// Genuine BitNet GEMM ADD:
// Weights in packed 2-bit ternary format (4 weights per byte)
// Bits: 0b00 -> 0, 0b01 -> +1, 0b10 -> -1
void bitnet_gemm_ternary(
    const int8_t* activations,
    const uint8_t* packed_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    float weight_scale,
    int n_threads
) {
    int bytes_per_row = (cols + 3) / 4;
    float final_scale = act_scale * weight_scale;

    auto worker = [&](int start_r, int end_r) {
        for (int r = start_r; r < end_r; ++r) {
            const uint8_t* w_row = packed_weights + r * bytes_per_row;
            int32_t accumulator = 0;

            int c = 0;
#ifdef __ARM_NEON
            // Process 16 ternary weights at once (4 packed bytes)
            int32x4_t v_acc = vdupq_n_s32(0);
            for (; c + 16 <= cols; c += 16) {
                int byte_idx = c / 4;
                for (int b = 0; b < 4; ++b) {
                    uint8_t byte = w_row[byte_idx + b];
                    int act_idx = c + b * 4;

                    // Unpack 4 ternary values
                    uint8_t w0 = (byte) & 0x03;
                    uint8_t w1 = (byte >> 2) & 0x03;
                    uint8_t w2 = (byte >> 4) & 0x03;
                    uint8_t w3 = (byte >> 6) & 0x03;

                    if (w0 == BITNET_WEIGHT_POS) accumulator += activations[act_idx];
                    else if (w0 == BITNET_WEIGHT_NEG) accumulator -= activations[act_idx];

                    if (w1 == BITNET_WEIGHT_POS) accumulator += activations[act_idx + 1];
                    else if (w1 == BITNET_WEIGHT_NEG) accumulator -= activations[act_idx + 1];

                    if (w2 == BITNET_WEIGHT_POS) accumulator += activations[act_idx + 2];
                    else if (w2 == BITNET_WEIGHT_NEG) accumulator -= activations[act_idx + 2];

                    if (w3 == BITNET_WEIGHT_POS) accumulator += activations[act_idx + 3];
                    else if (w3 == BITNET_WEIGHT_NEG) accumulator -= activations[act_idx + 3];
                }
            }
#endif
            for (; c < cols; ++c) {
                int byte_idx = c / 4;
                int shift = (c % 4) * 2;
                uint8_t w = (w_row[byte_idx] >> shift) & 0x03;

                if (w == BITNET_WEIGHT_POS) {
                    accumulator += activations[c];
                } else if (w == BITNET_WEIGHT_NEG) {
                    accumulator -= activations[c];
                }
                // If w == BITNET_WEIGHT_ZERO: skip (no operation!)
            }

            output[r] = accumulator * final_scale;
        }
    };

    if (n_threads <= 1 || rows < 8) {
        worker(0, rows);
    } else {
        std::vector<std::thread> workers;
        int chunk = (rows + n_threads - 1) / n_threads;
        for (int t = 0; t < n_threads; ++t) {
            int s = t * chunk;
            int e = std::min(rows, s + chunk);
            if (s < e) {
                workers.emplace_back(worker, s, e);
            }
        }
        for (auto& w : workers) {
            w.join();
        }
    }
}

void bitnet_rmsnorm(float* x, const float* weight, int size, float eps) {
    float sum = 0.0f;
    for (int i = 0; i < size; ++i) {
        sum += x[i] * x[i];
    }
    float scale = 1.0f / std::sqrt((sum / size) + eps);
    for (int i = 0; i < size; ++i) {
        x[i] = x[i] * scale * (weight ? weight[i] : 1.0f);
    }
}

void bitnet_softmax(float* x, int size) {
    float max_val = x[0];
    for (int i = 1; i < size; ++i) {
        if (x[i] > max_val) max_val = x[i];
    }
    float sum = 0.0f;
    for (int i = 0; i < size; ++i) {
        x[i] = std::exp(x[i] - max_val);
        sum += x[i];
    }
    float inv_sum = 1.0f / (sum > 0.0f ? sum : 1e-6f);
    for (int i = 0; i < size; ++i) {
        x[i] *= inv_sum;
    }
}

void bitnet_swiglu(float* gate, const float* up, int size) {
    for (int i = 0; i < size; ++i) {
        // silu(x) = x / (1 + exp(-x))
        float silu = gate[i] / (1.0f + std::exp(-gate[i]));
        gate[i] = silu * up[i];
    }
}
