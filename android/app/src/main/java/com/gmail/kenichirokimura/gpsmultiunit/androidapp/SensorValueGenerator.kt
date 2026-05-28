package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import kotlin.math.round
import kotlin.random.Random

object SensorValueGenerator {
    fun temperature(settings: AppSettings, random: Random = Random.Default): Double {
        val variation = random.nextDouble(
            -settings.temperatureVariation.toDouble(),
            settings.temperatureVariation.toDouble(),
        )
        return roundToTenth(settings.temperatureBase + variation)
    }

    fun humidity(settings: AppSettings, random: Random = Random.Default): Double {
        val variation = random.nextDouble(
            -settings.humidityVariation.toDouble(),
            settings.humidityVariation.toDouble(),
        )
        return roundToTenth((settings.humidityBase + variation).coerceIn(0.0, 100.0))
    }

    private fun roundToTenth(value: Double): Double = round(value * 10.0) / 10.0
}
