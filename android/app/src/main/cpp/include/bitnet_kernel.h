#ifndef BITNET_KERNEL_H
#define BITNET_KERNEL_H

#include <cstdint>
#include <cstddef>

#ifdef __ARM_NEON
#include <arm_neon.h>
#endif

// 1.58-bit ternary values encoded in 2 bits in Microsoft BitNet (i2_s / mad):
// 0b00 (0) = -1
// 0b01 (1) = 0 (sparse zero weights)
// 0b10 (2) = +1
// 0b11 (3) = 0 (unused)
#define BITNET_WEIGHT_NEG  0
#define BITNET_WEIGHT_ZERO 1
#define BITNET_WEIGHT_POS  2

// Quantize activations to int8 with dynamic scaling
void bitnet_quantize_activations(const float* input, int8_t* output, float* scale, int n);

// Real ternary GEMM: Matrix multiplication of activations (int8) by ternary weights {-1, 0, +1}
// No multiplications: Only additions, subtractions, and zero skips (GEMM ADD)
void bitnet_gemm_ternary(
    const int8_t* activations,
    const uint8_t* packed_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    float weight_scale,
    int n_threads
);

// BitNet TL1 (Ternary Lookup Table 1) accelerated kernel for ARM NEON
void bitnet_gemm_tl1_lut(
    const int8_t* activations,
    const uint8_t* packed_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    float weight_scale,
    int n_threads
);

// RMSNorm layer
void bitnet_rmsnorm(float* x, const float* weight, int size, float eps);

// Softmax
void bitnet_softmax(float* x, int size);

// Squared ReLU activation for BitNet b1.58 (2B4T / bitnet-25): gate = (max(0, gate)^2) * up
void bitnet_relu2_mul(float* gate, const float* up, int size);

// SwiGLU activation fallback: gate = silu(gate) * up
void bitnet_swiglu(float* gate, const float* up, int size);

// Rotary Position Embeddings (RoPE)
void bitnet_rope(float* x, int n_heads, int head_dim, int pos, float theta = 10000.0f);

// Convert IEEE 754 half-precision float (16-bit) to float32
float bitnet_fp16_to_fp32(uint16_t h);

// Q8_0 GEMM: Matrix multiplication of activations (int8) by Q8_0 weights (34-byte blocks: fp16 scale + 32 int8)
void bitnet_gemm_q8_0(
    const int8_t* activations,
    const uint8_t* q8_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    int n_threads
);

// Microsoft BitNet I2_S GEMM: 128-value blocks, interleaved by 32 into 32 bytes
void bitnet_gemm_i2_s(
    const int8_t* activations,
    const uint8_t* packed_weights,
    float* output,
    int rows,
    int cols,
    float act_scale,
    float weight_scale,
    int n_threads
);

#endif // BITNET_KERNEL_H
