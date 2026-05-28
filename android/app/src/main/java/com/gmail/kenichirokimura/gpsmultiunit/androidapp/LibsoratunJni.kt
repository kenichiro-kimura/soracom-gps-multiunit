package com.gmail.kenichirokimura.gpsmultiunit.androidapp

internal interface LibsoratunNativeBridge {
    fun isLibsoratunAvailable(): Boolean

    fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutSeconds: Int,
    ): String?
}

internal object LibsoratunJni : LibsoratunNativeBridge {
    init {
        System.loadLibrary("soratunbridge")
    }

    override fun isLibsoratunAvailable(): Boolean = nativeIsLibsoratunAvailable()

    override fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutSeconds: Int,
    ): String? = nativeSendUdp(configJson, body, port, timeoutSeconds)

    private external fun nativeIsLibsoratunAvailable(): Boolean

    private external fun nativeSendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutSeconds: Int,
    ): String?
}
