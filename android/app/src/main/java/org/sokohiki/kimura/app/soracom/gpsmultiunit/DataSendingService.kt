package org.sokohiki.kimura.app.soracom.gpsmultiunit

class DataSendingService(
    // Arc が未設定の場合は libsoratun / JNI 自体を初期化しない。
    // libsoratun を含むネイティブライブラリの初期化は ARC 送信時だけに限定する。
    private val arcService: SoracomArcService? = null,
    private val udpSendingService: DirectUdpSendingService = UdpSendingService(),
) {
    suspend fun send(jsonBody: String, settings: AppSettings): String {
        val arcConfig = settings.arcConfig.trim()

        // 空の設定を libsoratun に渡すとネイティブ側がプロセスを停止する場合があるため、
        // JNI 呼び出しより前に必ず処理する。
        if (arcConfig.isEmpty()) {
            return sendUdpFallbackOrThrow(jsonBody, settings)
        }

        try {
            val configuredArcService = arcService ?: LibsoratunArcService()
            configuredArcService.configure(arcConfig)
            return configuredArcService.sendUdp(jsonBody)
        } catch (error: SoracomArcError) {
            when (error) {
                is SoracomArcError.NotConfigured,
                is SoracomArcError.InvalidConfiguration,
                is SoracomArcError.LibraryUnavailable -> return sendUdpFallbackOrThrow(jsonBody, settings)
                is SoracomArcError.FallbackDisabled,
                is SoracomArcError.SendFailed -> throw error
            }
        }
    }

    private suspend fun sendUdpFallbackOrThrow(jsonBody: String, settings: AppSettings): String {
        if (!settings.arcUdpFallbackEnabled) {
            throw SoracomArcError.FallbackDisabled()
        }
        return "${udpSendingService.send(jsonBody)}$UDP_FALLBACK_SUFFIX"
    }

    companion object {
        const val UDP_FALLBACK_SUFFIX = " (UDP フォールバック)"
    }
}
