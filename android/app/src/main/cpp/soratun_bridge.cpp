#include <android/log.h>
#include <jni.h>
#include <dlfcn.h>

#include <cstdlib>
#include <mutex>
#include <string>
#include <vector>

namespace {

using SendUdpFn = char* (*)(const char*, const char*, int, int, int);

std::once_flag load_once;
void* libsoratun_handle = nullptr;
SendUdpFn send_udp_function = nullptr;
std::string libsoratun_load_error;

bool ensureLibsoratunLoaded() {
    std::call_once(load_once, []() {
        dlerror();
        libsoratun_handle = dlopen("libsoratun.so", RTLD_NOW | RTLD_LOCAL);
        if (libsoratun_handle != nullptr) {
            send_udp_function = reinterpret_cast<SendUdpFn>(dlsym(libsoratun_handle, "SendUDP"));
            if (send_udp_function == nullptr) {
                const char* error = dlerror();
                libsoratun_load_error = error != nullptr ? error : "unknown dlsym error";
                __android_log_print(ANDROID_LOG_ERROR, "soratunbridge", "Failed to resolve SendUDP: %s", libsoratun_load_error.c_str());
            }
        } else {
            const char* error = dlerror();
            libsoratun_load_error = error != nullptr ? error : "unknown dlopen error";
            __android_log_print(ANDROID_LOG_ERROR, "soratunbridge", "Failed to load libsoratun.so: %s", libsoratun_load_error.c_str());
        }
    });
    return libsoratun_handle != nullptr && send_udp_function != nullptr;
}

}  // namespace

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_gmail_kenichirokimura_gpsmultiunit_androidapp_LibsoratunJni_nativeIsLibsoratunAvailable(
    JNIEnv*,
    jobject
) {
    return ensureLibsoratunLoaded() ? JNI_TRUE : JNI_FALSE;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_gmail_kenichirokimura_gpsmultiunit_androidapp_LibsoratunJni_nativeSendUdp(
    JNIEnv* env,
    jobject,
    jstring config_json,
    jbyteArray body,
    jint port,
    jint timeout_seconds
) {
    if (!ensureLibsoratunLoaded()) {
        return nullptr;
    }

    const char* config_chars = env->GetStringUTFChars(config_json, nullptr);
    const jsize body_length = env->GetArrayLength(body);
    std::vector<char> body_bytes(static_cast<size_t>(body_length));
    env->GetByteArrayRegion(body, 0, body_length, reinterpret_cast<jbyte*>(body_bytes.data()));

    char* response = send_udp_function(
        config_chars,
        body_bytes.data(),
        static_cast<int>(body_length),
        static_cast<int>(port),
        static_cast<int>(timeout_seconds)
    );

    env->ReleaseStringUTFChars(config_json, config_chars);

    if (response == nullptr) {
        return nullptr;
    }

    // libsoratun's exported SendUDP function returns a C string allocated via Go's C.CString,
    // so the caller must release it with free(3) after converting it to a Java string.
    jstring result = env->NewStringUTF(response);
    free(response);
    return result;
}
