package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

class DataSendingServiceTest {
    @Test
    fun `uses Arc when config is present and library call succeeds`() = runBlocking {
        val arcService = FakeArcService(response = "200")
        val udpService = FakeUdpService(response = "204")
        val service = DataSendingService(arcService = arcService, udpSendingService = udpService)

        val response = service.send("""{"temp":25.0}""", AppSettings(arcConfig = VALID_ARC_JSON))

        assertEquals("200", response)
        assertEquals(1, arcService.sendCount)
        assertEquals(0, udpService.sendCount)
    }

    @Test
    fun `falls back to UDP when Arc config is invalid`() = runBlocking {
        val arcService = LibsoratunArcService(nativeBridge = FakeNativeBridge())
        val udpService = FakeUdpService(response = "204")
        val service = DataSendingService(arcService = arcService, udpSendingService = udpService)

        val response = service.send("""{"temp":25.0}""", AppSettings(arcConfig = "{invalid"))

        assertEquals("204${DataSendingService.UDP_FALLBACK_SUFFIX}", response)
        assertEquals(1, udpService.sendCount)
    }

    @Test
    fun `propagates Arc send failure when Arc is configured and send fails`() = runBlocking {
        val arcService = FakeArcService(sendError = SoracomArcError.SendFailed("Arc send failed"))
        val service = DataSendingService(arcService = arcService, udpSendingService = FakeUdpService(response = "204"))

        try {
            service.send("""{"temp":25.0}""", AppSettings(arcConfig = VALID_ARC_JSON))
            fail("Expected SoracomArcError.SendFailed")
        } catch (error: SoracomArcError.SendFailed) {
            assertEquals("送信に失敗しました: Arc send failed", error.message)
        }
    }

    private class FakeUdpService(
        private val response: String,
    ) : DirectUdpSendingService {
        var sendCount: Int = 0

        override suspend fun send(jsonBody: String): String {
            sendCount += 1
            return response
        }
    }

    private class FakeArcService(
        private val response: String = "200",
        private val sendError: SoracomArcError.SendFailed? = null,
    ) : SoracomArcService {
        var sendCount: Int = 0
        override val isConfigured: Boolean = true

        override fun configure(arcConfigJson: String) = Unit

        override suspend fun sendUdp(body: String, port: Int, timeoutSeconds: Int): String {
            sendCount += 1
            sendError?.let { throw it }
            return response
        }
    }

    private companion object {
        const val VALID_ARC_JSON = """
            {"privateKey":"private","logLevel":1,"arcSessionStatus":{"arcServerPeerPublicKey":"public","arcServerEndpoint":"example.com:11010","arcAllowedIPs":["100.127.0.0/16"],"arcClientPeerIpAddress":"10.0.0.1"}}
        """
    }
}
