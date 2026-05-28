#include <jni.h>
#include <dlfcn.h>

#include <cstdlib>
#include <vector>

namespace {

using SendUdpFn = char* (*)(const char*, const char*, int, int, int);

void* openLibsoratun() {
    return dlopen("libsoratun.so", RTLD_NOW | RTLD_LOCAL);
}

}  // namespace

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_gmail_kenichirokimura_gpsmultiunit_androidapp_LibsoratunJni_nativeIsLibsoratunAvailable(
    JNIEnv*,
    jobject
) {
    void* handle = openLibsoratun();
    if (handle == nullptr) {
        return JNI_FALSE;
    }
    dlclose(handle);
    return JNI_TRUE;
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
    void* handle = openLibsoratun();
    if (handle == nullptr) {
        return nullptr;
    }

    auto* send_udp = reinterpret_cast<SendUdpFn>(dlsym(handle, "SendUDP"));
    if (send_udp == nullptr) {
        dlclose(handle);
        return nullptr;
    }

    const char* config_chars = env->GetStringUTFChars(config_json, nullptr);
    const jsize body_length = env->GetArrayLength(body);
    std::vector<char> body_bytes(static_cast<size_t>(body_length));
    env->GetByteArrayRegion(body, 0, body_length, reinterpret_cast<jbyte*>(body_bytes.data()));

    char* response = send_udp(
        config_chars,
        body_bytes.data(),
        static_cast<int>(body_length),
        static_cast<int>(port),
        static_cast<int>(timeout_seconds)
    );

    env->ReleaseStringUTFChars(config_json, config_chars);
    dlclose(handle);

    if (response == nullptr) {
        return nullptr;
    }

    // libsoratun's exported SendUDP function returns a C string allocated via C.CString,
    // so the caller must release it with free(3) after converting it to a Java string.
    jstring result = env->NewStringUTF(response);
    free(response);
    return result;
}
