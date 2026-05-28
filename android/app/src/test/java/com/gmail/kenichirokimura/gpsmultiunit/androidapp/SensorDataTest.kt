package com.gmail.kenichirokimura.gpsmultiunit.androidapp

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

        assertTrue(json.contains(""lat":35.1"))
        assertTrue(json.contains(""lon":139.1"))
        assertTrue(json.contains(""temp":25.5"))
        assertTrue(json.contains(""humi":60.0"))
        assertTrue(json.contains(""type":1"))
    }
}
