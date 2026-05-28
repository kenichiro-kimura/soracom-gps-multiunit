package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SensorValueGeneratorTest {
    @Test
    fun `temperature stays within configured range`() {
        val settings = AppSettings(temperatureBase = 25f, temperatureVariation = 2f)
        val value = SensorValueGenerator.temperature(settings, Random(0))

        assertTrue(value in 23.0..27.0)
    }

    @Test
    fun `humidity is clamped between zero and one hundred`() {
        val settings = AppSettings(humidityBase = 98f, humidityVariation = 10f)
        repeat(10) {
            val value = SensorValueGenerator.humidity(settings, Random(it))
            assertTrue(value in 0.0..100.0)
        }
    }

    @Test
    fun `temperature rounds to a single decimal place`() {
        val settings = AppSettings(temperatureBase = 25f, temperatureVariation = 0f)
        assertEquals(25.0, SensorValueGenerator.temperature(settings, Random(0)), 0.0)
    }
}
