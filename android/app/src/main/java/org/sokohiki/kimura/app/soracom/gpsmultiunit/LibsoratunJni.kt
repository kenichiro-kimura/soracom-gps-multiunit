package org.sokohiki.kimura.app.soracom.gpsmultiunit

interface LibsoratunNativeBridge {
    fun isLibsoratunAvailable(): Boolean

    fun loadErrorMessage(): String? = null
    fun loadError(): MessageI18n.Message? = loadErrorMessage()?.let {
        MessageI18n.Message(MessageI18n.MessageKey.RAW_DETAIL, it)
    }

    fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutMillis: Int,
    ): String?
}

internal object LibsoratunJni : LibsoratunNativeBridge {
    private val loadFailed: Boolean = try {
        System.loadLibrary("soratunbridge")
        false
    } catch (_: UnsatisfiedLinkError) {
        true
    }

    override fun isLibsoratunAvailable(): Boolean = !loadFailed && nativeIsLibsoratunAvailable()

    override fun loadErrorMessage(): String? = loadError()?.let(MessageI18n::text)

    override fun loadError(): MessageI18n.Message? =
        if (loadFailed) MessageI18n.Message(MessageI18n.MessageKey.JNI_LOAD_FAILED) else null

    override fun sendUdp(
        configJson: String,
        body: ByteArray,
        port: Int,
        timeoutMillis: Int,
    ): String? {
        check(!loadFailed) { loadErrorMessage()!! }
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
