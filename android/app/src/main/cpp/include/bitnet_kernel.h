#ifndef BITNET_KERNEL_H
#define BITNET_KERNEL_H

#include <cstdint>
#include <cstddef>

#ifdef __ARM_NEON
#include <arm_neon.h>
#endif

// 1.58-bit ternary values encoded in 2 bits:
// 0b00 = 0
// 0b01 = +1
// 0b10 = -1
// 0b11 = reserved / unused
#define BITNET_WEIGHT_ZERO 0
#define BITNET_WEIGHT_POS  1
#define BITNET_WEIGHT_NEG  2

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

// SwiGLU activation: gate = silu(gate) * up
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
