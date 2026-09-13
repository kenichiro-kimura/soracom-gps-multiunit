package org.sokohiki.kimura.app.soracom.gpsmultiunit

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SensorDataTest {
    @Test
    fun `toJsonString preserves sensor payload contract`() {
        val payload = SensorData(
            lat = 35.1,
            lon = 139.1,
            temp = 25.5,
            humi = 60.0,
            x = 1.0,
            y = -2.0,
            z = 980.0,
            bat = 3,
            rs = 4,
            type = SendType.MANUAL,
        )

        val json = payload.toJsonString()

        assertEquals(
            "{\"lat\":35.1,\"lon\":139.1,\"bat\":3,\"rs\":4,\"temp\":25.5," +
                "\"humi\":60.0,\"x\":1.0,\"y\":-2.0,\"z\":980.0,\"type\":1}",
            json,
        )
    }

    @Test
    fun `toJsonString includes null GPS fields when location is unavailable`() {
        val payload = SensorData(type = SendType.MANUAL)

        val json = payload.toJsonString()

        assertTrue(json.contains("\"lat\":null"))
        assertTrue(json.contains("\"lon\":null"))
    }
}
