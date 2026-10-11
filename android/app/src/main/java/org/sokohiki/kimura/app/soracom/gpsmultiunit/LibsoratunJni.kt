package org.sokohiki.kimura.app.soracom.gpsmultiunit

interface LibsoratunNativeBridge {
    fun isLibsoratunAvailable(): Boolean

    fun loadErrorMessage(): String? = null

    fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutMillis: Int,
    ): String?
}

internal object LibsoratunJni : LibsoratunNativeBridge {
    private val loadErrorMessage: String? = try {
        System.loadLibrary("soratunbridge")
        null
    } catch (_: UnsatisfiedLinkError) {
        MessageI18n.jniLoadFailed()
    }

    override fun isLibsoratunAvailable(): Boolean = loadErrorMessage == null && nativeIsLibsoratunAvailable()

    override fun loadErrorMessage(): String? = loadErrorMessage

    override fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutMillis: Int,
    ): String? {
        check(loadErrorMessage == null) { loadErrorMessage!! }
        return nativeSendUdp(configJson, body, port, timeoutMillis)
    }

    private external fun nativeIsLibsoratunAvailable(): Boolean

    private external fun nativeSendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutMillis: Int,
    ): String?
}
