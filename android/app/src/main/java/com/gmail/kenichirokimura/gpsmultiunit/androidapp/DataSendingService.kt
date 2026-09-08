package com.gmail.kenichirokimura.gpsmultiunit.androidapp

class DataSendingService(
    private val arcService: SoracomArcService = LibsoratunArcService(),
    private val udpSendingService: DirectUdpSendingService = UdpSendingService(),
) {
    suspend fun send(jsonBody: String, settings: AppSettings): String {
        val arcConfig = settings.arcConfig.trim()

        if (arcConfig.isNotEmpty()) {
            try {
                arcService.configure(arcConfig)
                return arcService.sendUdp(jsonBody)
            } catch (error: SoracomArcError) {
                when (error) {
                    is SoracomArcError.NotConfigured,
                    is SoracomArcError.InvalidConfiguration,
                    is SoracomArcError.LibraryUnavailable -> Unit
                    is SoracomArcError.SendFailed -> throw error
                }
            }
        }

        return "${udpSendingService.send(jsonBody)}$UDP_FALLBACK_SUFFIX"
    }

    companion object {
        const val UDP_FALLBACK_SUFFIX = " (UDP フォールバック)"
    }
}
