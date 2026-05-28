package com.gmail.kenichirokimura.gpsmultiunit.androidapp

data class AppSettings(
    val temperatureBase: Float = 25f,
    val temperatureVariation: Float = 2f,
    val humidityBase: Float = 60f,
    val humidityVariation: Float = 5f,
    val rsValue: Int = 3,
    val batValue: Int = 3,
    val autoSendEnabled: Boolean = false,
    val sendingIntervalSeconds: Int = 60,
)
