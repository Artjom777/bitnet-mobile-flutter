#ifndef BITNET_JNI_DEFS_H
#define BITNET_JNI_DEFS_H

#if defined(__ANDROID__)
#include <jni.h>
#elif __has_include(<jni.h>)
#include <jni.h>
#else

#include <cstdint>
#include <cstddef>

typedef uint8_t  jboolean;
typedef int8_t   jbyte;
typedef uint16_t jchar;
typedef int16_t  jshort;
typedef int32_t  jint;
typedef int64_t  jlong;
typedef float    jfloat;
typedef double   jdouble;
typedef jint     jsize;

struct _jobject {};
typedef struct _jobject *jobject;
typedef jobject jclass;
typedef jobject jstring;
typedef jobject jarray;
typedef jobject jfloatArray;
struct _jmethodID;
typedef struct _jmethodID *jmethodID;

#define JNI_FALSE 0
#define JNI_TRUE 1
#define JNI_VERSION_1_6 0x00010006

#if defined(_WIN32)
#define JNIEXPORT __declspec(dllexport)
#define JNICALL __stdcall
#else
#define JNIEXPORT __attribute__((visibility("default")))
#define JNICALL
#endif

typedef void JavaVM;

struct JNINativeInterface {
    void* reserved0;
    void* reserved1;
    void* reserved2;
    void* reserved3;
    jclass (*FindClass)(void*, const char*);
    void* reserved4;
    void* reserved5;
    void* reserved6;
    void* reserved7;
    void* reserved8;
    void* reserved9;
    void* reserved10;
    void* reserved11;
    void* reserved12;
    void* reserved13;
    void (*ExceptionClear)(void*);
    void* reserved14;
    void* reserved15;
    void* reserved16;
    void* reserved17;
    void* reserved18;
    void* reserved19;
    void* reserved20;
    void (*DeleteLocalRef)(void*, jobject);
    void* reserved21;
    void* reserved22;
    void* reserved23;
    jclass (*GetObjectClass)(void*, jobject);
    void* reserved24;
    jmethodID (*GetMethodID)(void*, jclass, const char*, const char*);
    void* reserved25;
    void* reserved26;
    void* reserved27;
    void* reserved28;
    void* reserved29;
    void* reserved30;
    void* reserved31;
    void* reserved32;
    void* reserved33;
    void* reserved34;
    void* reserved35;
    void* reserved36;
    void (*CallVoidMethod)(void*, jobject, jmethodID, ...);
    void* reserved37[80];
    jstring (*NewStringUTF)(void*, const char*);
    const char* (*GetStringUTFChars)(void*, jstring, jboolean*);
    void (*ReleaseStringUTFChars)(void*, jstring, const char*);
    jsize (*GetArrayLength)(void*, jarray);
    void* reserved38[20];
    void (*SetFloatArrayRegion)(void*, jfloatArray, jsize, jsize, const jfloat*);
};

struct JNIEnv_ {
    const struct JNINativeInterface* functions;

    const char* GetStringUTFChars(jstring str, jboolean* isCopy) {
        return functions->GetStringUTFChars(this, str, isCopy);
    }
    void ReleaseStringUTFChars(jstring str, const char* chars) {
        functions->ReleaseStringUTFChars(this, str, chars);
    }
    jclass GetObjectClass(jobject obj) {
        return functions->GetObjectClass(this, obj);
    }
    jmethodID GetMethodID(jclass clazz, const char* name, const char* sig) {
        return functions->GetMethodID(this, clazz, name, sig);
    }
    template<typename... Args>
    void CallVoidMethod(jobject obj, jmethodID methodID, Args... args) {
        functions->CallVoidMethod(this, obj, methodID, args...);
    }
    void ExceptionClear() {
        functions->ExceptionClear(this);
    }
    jstring NewStringUTF(const char* bytes) {
        return functions->NewStringUTF(this, bytes);
    }
    void DeleteLocalRef(jobject obj) {
        functions->DeleteLocalRef(this, obj);
    }
    jsize GetArrayLength(jarray array) {
        return functions->GetArrayLength(this, array);
    }
    void SetFloatArrayRegion(jfloatArray array, jsize start, jsize len, const jfloat* buf) {
        functions->SetFloatArrayRegion(this, array, start, len, buf);
    }
};
typedef struct JNIEnv_ JNIEnv;

#endif

#endif // BITNET_JNI_DEFS_H
