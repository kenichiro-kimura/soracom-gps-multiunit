package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SoracomArcServiceTest {
    @Test
    fun `configure accepts WireGuard config and converts it for libsoratun`() = runBlocking {
        val bridge = FakeNativeBridge(response = "204")
        val service = LibsoratunArcService(nativeBridge = bridge)

        service.configure(
            """
            [Interface]
            PrivateKey = private-key
            Address = 10.0.0.1/32

            [Peer]
            PublicKey = public-key
            AllowedIPs = 100.127.0.0/16, 100.127.64.0/18
            Endpoint = example.com:11010
            """.trimIndent()
        )
        service.sendUdp("""{"temp":25.0}""")

        assertTrue(bridge.lastConfigJson?.contains("arcServerPeerPublicKey") == true)
        assertTrue(bridge.lastConfigJson?.contains("10.0.0.1") == true)
        assertTrue(bridge.lastConfigJson?.contains("100.127.0.0/16") == true)
    }

    @Test
    fun `configure converts soratun json into libsoratun json`() = runBlocking {
        val bridge = FakeNativeBridge(response = "204")
        val service = LibsoratunArcService(nativeBridge = bridge)

        service.configure(
            """
            {"privateKey":"private-key","address":"10.0.0.1/32","publicKey":"public-key","allowedIPs":["100.127.0.0/16"],"endpoint":"example.com:11010"}
            """.trimIndent()
        )
        service.sendUdp("""{"temp":25.0}""")

        assertTrue(bridge.lastConfigJson?.contains("arcSessionStatus") == true)
        assertTrue(bridge.lastConfigJson?.contains("arcClientPeerIpAddress") == true)
    }

    @Test
    fun `sendUdp throws when libsoratun is unavailable`() = runBlocking {
        val service = LibsoratunArcService(nativeBridge = FakeNativeBridge(isAvailable = false))
        service.configure(
            """
            {"privateKey":"private-key","logLevel":1,"arcSessionStatus":{"arcServerPeerPublicKey":"public-key","arcServerEndpoint":"example.com:11010","arcAllowedIPs":["100.127.0.0/16"],"arcClientPeerIpAddress":"10.0.0.1"}}
            """.trimIndent()
        )

        try {
            service.sendUdp("""{"temp":25.0}""")
            fail("Expected SoracomArcError.LibraryUnavailable")
        } catch (_: SoracomArcError.LibraryUnavailable) {
            Unit
        }
    }
}

internal class FakeNativeBridge(
    private val isAvailable: Boolean = true,
    private val response: String? = "204",
) : LibsoratunNativeBridge {
    var lastConfigJson: String? = null

    override fun isLibsoratunAvailable(): Boolean = isAvailable

    override fun sendUdp(configJson: String, body: ByteArray, port: Int, timeoutSeconds: Int): String? {
        lastConfigJson = configJson
        return response
    }
}
