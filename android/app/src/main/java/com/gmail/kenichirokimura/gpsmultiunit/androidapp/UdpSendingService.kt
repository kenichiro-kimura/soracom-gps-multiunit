package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress

interface DirectUdpSendingService {
    suspend fun send(jsonBody: String): String
}

class UdpSendingService(
    private val host: String = UNIFIED_ENDPOINT_HOST,
    private val port: Int = UNIFIED_ENDPOINT_PORT,
    private val timeoutMillis: Int = UDP_TIMEOUT_MILLIS,
) : DirectUdpSendingService {
    override suspend fun send(jsonBody: String): String = withContext(Dispatchers.IO) {
        val address = InetAddress.getByName(host)
        val payload = jsonBody.toByteArray(Charsets.UTF_8)
        DatagramSocket().use { socket ->
            socket.soTimeout = timeoutMillis
            socket.connect(address, port)
            socket.send(DatagramPacket(payload, payload.size, address, port))

            val responseBuffer = ByteArray(65_536)
            val responsePacket = DatagramPacket(responseBuffer, responseBuffer.size)
            socket.receive(responsePacket)

            val response = responsePacket.data
                .copyOf(responsePacket.length)
                .toString(Charsets.UTF_8)

            require(response.isNotBlank()) { "レスポンスが空でした。" }
            require(response.first() == '2' || response.first() == '{') {
                "不正なレスポンス: $response"
            }
            response
        }
    }

    private companion object {
        const val UNIFIED_ENDPOINT_HOST = "uni.soracom.io"
        const val UNIFIED_ENDPOINT_PORT = 23080
        const val UDP_TIMEOUT_MILLIS = 6_000
    }
}
