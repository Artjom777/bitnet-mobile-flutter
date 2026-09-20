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

// RMSNorm layer
void bitnet_rmsnorm(float* x, const float* weight, int size, float eps);

// Softmax
void bitnet_softmax(float* x, int size);

// SwiGLU activation: gate = silu(gate) * up
void bitnet_swiglu(float* gate, const float* up, int size);

// Rotary Positional Embedding (RoPE)
void bitnet_rope(float* q, float* k, int n_heads, int head_dim, int pos, float theta = 10000.0f);

#endif // BITNET_KERNEL_H
