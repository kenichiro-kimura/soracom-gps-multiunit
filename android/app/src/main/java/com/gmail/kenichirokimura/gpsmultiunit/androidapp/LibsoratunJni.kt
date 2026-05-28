package com.gmail.kenichirokimura.gpsmultiunit.androidapp

internal interface LibsoratunNativeBridge {
    fun isLibsoratunAvailable(): Boolean

    fun loadErrorMessage(): String? = null

    fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutSeconds: Int,
    ): String?
}

internal object LibsoratunJni : LibsoratunNativeBridge {
    private val loadErrorMessage: String? = try {
        System.loadLibrary("soratunbridge")
        null
    } catch (_: UnsatisfiedLinkError) {
        "soratunbridge の読み込みに失敗しました。`android/app/src/main/jniLibs/` に libsoratun.so を配置して再ビルドしてください。"
    }

    override fun isLibsoratunAvailable(): Boolean = loadErrorMessage == null && nativeIsLibsoratunAvailable()

    override fun loadErrorMessage(): String? = loadErrorMessage

    override fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutSeconds: Int,
    ): String? {
        check(loadErrorMessage == null) { loadErrorMessage }
        return nativeSendUdp(configJson, body, port, timeoutSeconds)
    }

    private external fun nativeIsLibsoratunAvailable(): Boolean

    private external fun nativeSendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutSeconds: Int,
    ): String?
}
