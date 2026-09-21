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

#if defined(__aarch64__) && defined(__ARM_NEON)
    float32x4_t vs = vdupq_n_f32(s);
    float32x4_t vmin_val = vdupq_n_f32(-127.0f);
    float32x4_t vmax_val = vdupq_n_f32(127.0f);
    int j = 0;
    for (; j + 4 <= n; j += 4) {
        float32x4_t vin = vld1q_f32(input + j);
        float32x4_t vscaled = vmulq_f32(vin, vs);
        vscaled = vminq_f32(vmaxq_f32(vscaled, vmin_val), vmax_val);
        int32x4_t vint = vcvtnq_s32_f32(vscaled);
        output[j + 0] = static_cast<int8_t>(vgetq_lane_s32(vint, 0));
        output[j + 1] = static_cast<int8_t>(vgetq_lane_s32(vint, 1));
        output[j + 2] = static_cast<int8_t>(vgetq_lane_s32(vint, 2));
        output[j + 3] = static_cast<int8_t>(vgetq_lane_s32(vint, 3));
    }
    for (; j < n; ++j) {
        float val = input[j] * s;
        val = std::clamp(val, -127.0f, 127.0f);
        output[j] = static_cast<int8_t>(std::round(val));
    }
#else
    for (int i = 0; i < n; ++i) {
        float val = input[i] * s;
        val = std::clamp(val, -127.0f, 127.0f);
        output[i] = static_cast<int8_t>(std::round(val));
    }
#endif
}

// BitNet 1.58b GEMM ADD:
// Weights in packed 2-bit ternary format (4 weights per byte):
// 0b00 -> 0 (skip)
// 0b01 -> +1 (add activation)
// 0b10 -> -1 (subtract activation)
// 0b11 -> reserved (treated as 0)
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
    const int bytes_per_row = (cols + 3) / 4;
    const float final_scale = act_scale * weight_scale;

    auto worker = [&](int start_r, int end_r) {
        for (int r = start_r; r < end_r; ++r) {
            const uint8_t* w_row = packed_weights + r * bytes_per_row;
            int32_t accumulator = 0;

            int c = 0;
#ifdef __ARM_NEON
            // Process 16 activations / 4 packed bytes at a time
            for (; c + 16 <= cols; c += 16) {
                int byte_idx = c / 4;
                for (int b = 0; b < 4; ++b) {
                    uint8_t byte = w_row[byte_idx + b];
                    if (byte == 0) continue; // All 4 weights are zero, fast skip

                    int act_idx = c + b * 4;
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

// BitNet TL1 (Ternary Lookup Table 1) accelerated kernel for ARM NEON
// Preconstructs combination lookup tables for groups of activations and accumulates
void bitnet_gemm_tl1_lut(
    const int8_t* activations,
    const uint8_t* packed_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    float weight_scale,
    int n_threads
) {
    // TL1 table lookup can accelerate dense evaluation; fallback to direct GEMM ADD
    bitnet_gemm_ternary(activations, packed_weights, output, rows, cols, act_scale, weight_scale, n_threads);
}

void bitnet_rmsnorm(float* x, const float* weight, int size, float eps) {
    float sum = 0.0f;
#if defined(__aarch64__) && defined(__ARM_NEON)
    float32x4_t vsum = vdupq_n_f32(0.0f);
    int i = 0;
    for (; i + 4 <= size; i += 4) {
        float32x4_t v = vld1q_f32(x + i);
        vsum = vmlaq_f32(vsum, v, v);
    }
    sum = vaddvq_f32(vsum);
    for (; i < size; ++i) {
        sum += x[i] * x[i];
    }
#else
    for (int i = 0; i < size; ++i) {
        sum += x[i] * x[i];
    }
#endif

    float scale = 1.0f / std::sqrt((sum / static_cast<float>(size)) + eps);

#if defined(__aarch64__) && defined(__ARM_NEON)
    float32x4_t vscale = vdupq_n_f32(scale);
    int j = 0;
    if (weight) {
        for (; j + 4 <= size; j += 4) {
            float32x4_t vx = vld1q_f32(x + j);
            float32x4_t vw = vld1q_f32(weight + j);
            float32x4_t vres = vmulq_f32(vmulq_f32(vx, vscale), vw);
            vst1q_f32(x + j, vres);
        }
        for (; j < size; ++j) {
            x[j] = x[j] * scale * weight[j];
        }
    } else {
        for (; j + 4 <= size; j += 4) {
            float32x4_t vx = vld1q_f32(x + j);
            vst1q_f32(x + j, vmulq_f32(vx, vscale));
        }
        for (; j < size; ++j) {
            x[j] = x[j] * scale;
        }
    }
#else
    for (int i = 0; i < size; ++i) {
        x[i] = x[i] * scale * (weight ? weight[i] : 1.0f);
    }
#endif
}

void bitnet_softmax(float* x, int size) {
    if (size <= 0) return;
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
        float g = gate[i];
        float silu = g / (1.0f + std::exp(-g));
        gate[i] = silu * up[i];
    }
}

void bitnet_rope(float* q, float* k, int n_heads, int head_dim, int pos, float theta) {
    for (int h = 0; h < n_heads; ++h) {
        float* q_head = q + h * head_dim;
        float* k_head = k + h * head_dim;

        for (int i = 0; i < head_dim; i += 2) {
            float freq = 1.0f / std::pow(theta, static_cast<float>(i) / static_cast<float>(head_dim));
            float val = static_cast<float>(pos) * freq;
            float cos_v = std::cos(val);
            float sin_v = std::sin(val);

            // Rotate Q
            float q0 = q_head[i];
            float q1 = q_head[i + 1];
            q_head[i]     = q0 * cos_v - q1 * sin_v;
            q_head[i + 1] = q0 * sin_v + q1 * cos_v;

            // Rotate K
            float k0 = k_head[i];
            float k1 = k_head[i + 1];
            k_head[i]     = k0 * cos_v - k1 * sin_v;
            k_head[i + 1] = k0 * sin_v + k1 * cos_v;
        }
    }
}

float bitnet_fp16_to_fp32(uint16_t h) {
    uint32_t w = static_cast<uint32_t>(h & 0x7fff) << 13;
    uint32_t sign = static_cast<uint32_t>(h & 0x8000) << 16;
    uint32_t exp = (h >> 10) & 0x1f;
    if (exp == 0x1f) {
        return 0.0f; // Inf or NaN
    }
    if (exp == 0) {
        if ((h & 0x03ff) == 0) return 0.0f;
        float val = static_cast<float>(h & 0x03ff) / static_cast<float>(1 << 24);
        return (h & 0x8000) ? -val : val;
    }
    w += static_cast<uint32_t>(127 - 15) << 23;
    w |= sign;
    float f = 0.0f;
    std::memcpy(&f, &w, sizeof(f));
    return f;
}

void bitnet_gemm_q8_0(
    const int8_t* activations,
    const uint8_t* q8_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    int n_threads
) {
    const int blocks_per_row = cols / 32;
    const size_t row_stride_bytes = static_cast<size_t>(blocks_per_row) * 34;

    auto worker = [&](int start_r, int end_r) {
        for (int r = start_r; r < end_r; ++r) {
            const uint8_t* row_ptr = q8_weights + r * row_stride_bytes;
            float row_sum = 0.0f;

            for (int b = 0; b < blocks_per_row; ++b) {
                const uint8_t* blk = row_ptr + b * 34;
                uint16_t d_raw;
                std::memcpy(&d_raw, blk, sizeof(uint16_t));
                float d = bitnet_fp16_to_fp32(d_raw);
                const int8_t* qs = reinterpret_cast<const int8_t*>(blk + 2);
                const int8_t* act = activations + b * 32;

                int32_t acc = 0;
#if defined(__aarch64__) && defined(__ARM_NEON)
                int8x16_t a0 = vld1q_s8(act);
                int8x16_t w0 = vld1q_s8(qs);
                int8x16_t a1 = vld1q_s8(act + 16);
                int8x16_t w1 = vld1q_s8(qs + 16);

                int16x8_t p0_l = vmull_s8(vget_low_s8(a0), vget_low_s8(w0));
                int16x8_t p0_h = vmull_s8(vget_high_s8(a0), vget_high_s8(w0));
                int16x8_t p1_l = vmull_s8(vget_low_s8(a1), vget_low_s8(w1));
                int16x8_t p1_h = vmull_s8(vget_high_s8(a1), vget_high_s8(w1));

                int32x4_t s = vpaddlq_s16(p0_l);
                s = vpadalq_s16(s, p0_h);
                s = vpadalq_s16(s, p1_l);
                s = vpadalq_s16(s, p1_h);

                acc = vgetq_lane_s32(s, 0) + vgetq_lane_s32(s, 1) + vgetq_lane_s32(s, 2) + vgetq_lane_s32(s, 3);
#else
                for (int i = 0; i < 32; ++i) {
                    acc += static_cast<int32_t>(act[i]) * static_cast<int32_t>(qs[i]);
                }
#endif
                row_sum += static_cast<float>(acc) * (d * act_scale);
            }
            output[r] = row_sum;
        }
    };

    if (n_threads <= 1 || rows < 16) {
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

void bitnet_gemm_i2_s(
    const int8_t* activations,
    const uint8_t* packed_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    float weight_scale,
    int n_threads
) {
    const int bytes_per_row = cols / 4;
    const int blocks_per_row = cols / 128;
    const float final_scale = act_scale * weight_scale;

    auto worker = [&](int start_r, int end_r) {
        for (int r = start_r; r < end_r; ++r) {
            const uint8_t* row_bytes = packed_weights + static_cast<size_t>(r) * bytes_per_row;
            int32_t accumulator = 0;

            for (int blk = 0; blk < blocks_per_row; ++blk) {
                const uint8_t* blk_ptr = row_bytes + blk * 32;
                const int8_t* act_blk = activations + blk * 128;

                const int8_t* act0 = act_blk + 0 * 32;
                const int8_t* act1 = act_blk + 1 * 32;
                const int8_t* act2 = act_blk + 2 * 32;
                const int8_t* act3 = act_blk + 3 * 32;

                for (int gp = 0; gp < 32; ++gp) {
                    uint8_t byte = blk_ptr[gp];
                    if (byte == 0x55) continue; // All four are code 1 (zero: 0b01010101)

                    uint8_t c0 = (byte >> 6) & 3;
                    uint8_t c1 = (byte >> 4) & 3;
                    uint8_t c2 = (byte >> 2) & 3;
                    uint8_t c3 = (byte >> 0) & 3;

                    if (c0 == 2) accumulator += act0[gp];
                    else if (c0 == 0) accumulator -= act0[gp];

                    if (c1 == 2) accumulator += act1[gp];
                    else if (c1 == 0) accumulator -= act1[gp];

                    if (c2 == 2) accumulator += act2[gp];
                    else if (c2 == 0) accumulator -= act2[gp];

                    if (c3 == 2) accumulator += act3[gp];
                    else if (c3 == 0) accumulator -= act3[gp];
                }
            }

            output[r] = accumulator * final_scale;
        }
    };

    if (n_threads <= 1 || rows < 16) {
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


