#include "jni_defs.h"
#include <string>
#include <vector>
#include <memory>
#include <mutex>
#include "bitnet_engine.h"

// Reference external engine functions from bitnet_ffi.cpp
extern BitNetEngine* get_global_bitnet_engine();
extern std::mutex& get_global_bitnet_engine_mutex();
extern void update_cached_telemetry(const BitNetTelemetry& t);

extern "C" {

// C FFI functions defined in bitnet_ffi.cpp
int bitnet_init(const char* model_path, int n_threads, int n_ctx);
int bitnet_load_model(const char* model_path);
int bitnet_unload_model();
int bitnet_is_model_loaded();
void bitnet_get_telemetry(float* out_tok_s, int* out_ttft_ms, float* out_ram_mb, int* out_active_threads, float* out_temp_c);
void bitnet_free();

// ==========================================
// JNI Implementation for com.bitnet.ai.BitNetNative
// ==========================================

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_BitNetNative_nativeInit(
    JNIEnv* env,
    jclass /* clazz */,
    jstring j_model_path,
    jint n_threads,
    jint n_ctx
) {
    const char* path_chars = j_model_path ? env->GetStringUTFChars(j_model_path, nullptr) : nullptr;
    int res = bitnet_init(path_chars ? path_chars : "", n_threads, n_ctx);
    if (path_chars) {
        env->ReleaseStringUTFChars(j_model_path, path_chars);
    }
    return res;
}

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_BitNetNative_nativeLoadModel(
    JNIEnv* env,
    jclass /* clazz */,
    jstring j_model_path
) {
    if (!j_model_path) return 0;
    const char* path_chars = env->GetStringUTFChars(j_model_path, nullptr);
    int res = bitnet_load_model(path_chars);
    env->ReleaseStringUTFChars(j_model_path, path_chars);
    return res;
}

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_BitNetNative_nativeUnloadModel(
    JNIEnv* /* env */,
    jclass /* clazz */
) {
    return bitnet_unload_model();
}

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_BitNetNative_nativeIsModelLoaded(
    JNIEnv* /* env */,
    jclass /* clazz */
) {
    return bitnet_is_model_loaded();
}

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_BitNetNative_nativeGenerateStream(
    JNIEnv* env,
    jclass /* clazz */,
    jstring j_prompt,
    jint max_tokens,
    jfloat temperature,
    jfloat top_p,
    jfloat rep_penalty,
    jobject j_callback
) {
    if (!j_prompt) return -1;
    const char* prompt_chars = env->GetStringUTFChars(j_prompt, nullptr);
    std::string prompt(prompt_chars ? prompt_chars : "");
    if (prompt_chars) {
        env->ReleaseStringUTFChars(j_prompt, prompt_chars);
    }

    std::lock_guard<std::mutex> lock(get_global_bitnet_engine_mutex());
    BitNetEngine* engine = get_global_bitnet_engine();
    if (!engine) return -1;

    jclass callback_class = j_callback ? env->GetObjectClass(j_callback) : nullptr;
    jmethodID on_token_method = nullptr;
    if (callback_class) {
        // Try void onToken(String token, boolean isDone)
        on_token_method = env->GetMethodID(callback_class, "onToken", "(Ljava/lang/String;Z)V");
        if (!on_token_method) {
            env->ExceptionClear();
            // Fallback: void onToken(String token, int isDone)
            on_token_method = env->GetMethodID(callback_class, "onToken", "(Ljava/lang/String;I)V");
        }
    }

    int tokens = engine->generate_stream(
        prompt,
        max_tokens,
        temperature,
        top_p,
        rep_penalty,
        [&](const std::string& token, bool is_done) {
            if (j_callback && on_token_method) {
                jstring j_token = env->NewStringUTF(token.c_str());
                env->CallVoidMethod(j_callback, on_token_method, j_token, is_done ? JNI_TRUE : JNI_FALSE);
                env->DeleteLocalRef(j_token);
            }
        }
    );

    update_cached_telemetry(engine->get_telemetry());
    return tokens;
}

JNIEXPORT void JNICALL
Java_com_bitnet_ai_BitNetNative_nativeGetTelemetry(
    JNIEnv* env,
    jclass /* clazz */,
    jfloatArray j_out_array
) {
    if (!j_out_array) return;
    jsize len = env->GetArrayLength(j_out_array);
    if (len < 5) return;

    float tok_s = 0.0f;
    int ttft_ms = 0;
    float ram_mb = 0.0f;
    int active_threads = 0;
    float temp_c = 0.0f;

    bitnet_get_telemetry(&tok_s, &ttft_ms, &ram_mb, &active_threads, &temp_c);

    float stats[5] = {
        tok_s,
        static_cast<float>(ttft_ms),
        ram_mb,
        static_cast<float>(active_threads),
        temp_c
    };

    env->SetFloatArrayRegion(j_out_array, 0, 5, stats);
}

JNIEXPORT void JNICALL
Java_com_bitnet_ai_BitNetNative_nativeFree(
    JNIEnv* /* env */,
    jclass /* clazz */
) {
    bitnet_free();
}

// ==========================================
// MainActivity mappings for direct JNI calls
// ==========================================

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_MainActivity_nativeInit(
    JNIEnv* env,
    jobject /* thiz */,
    jstring j_model_path,
    jint n_threads,
    jint n_ctx
) {
    return Java_com_bitnet_ai_BitNetNative_nativeInit(env, nullptr, j_model_path, n_threads, n_ctx);
}

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_MainActivity_nativeLoadModel(
    JNIEnv* env,
    jobject /* thiz */,
    jstring j_model_path
) {
    return Java_com_bitnet_ai_BitNetNative_nativeLoadModel(env, nullptr, j_model_path);
}

JNIEXPORT jint JNICALL
Java_com_bitnet_ai_MainActivity_nativeGenerateStream(
    JNIEnv* env,
    jobject /* thiz */,
    jstring j_prompt,
    jint max_tokens,
    jfloat temperature,
    jfloat top_p,
    jfloat rep_penalty,
    jobject j_callback
) {
    return Java_com_bitnet_ai_BitNetNative_nativeGenerateStream(
        env, nullptr, j_prompt, max_tokens, temperature, top_p, rep_penalty, j_callback
    );
}

JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM* /* vm */, void* /* reserved */) {
    return JNI_VERSION_1_6;
}

} // extern "C"
