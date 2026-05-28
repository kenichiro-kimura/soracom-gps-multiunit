package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import android.content.Context
import android.content.SharedPreferences

class SettingsRepository(context: Context) {
    private val preferences: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun load(): AppSettings = AppSettings(
        temperatureBase = preferences.getFloat(KEY_TEMPERATURE_BASE, 25f),
        temperatureVariation = preferences.getFloat(KEY_TEMPERATURE_VARIATION, 2f),
        humidityBase = preferences.getFloat(KEY_HUMIDITY_BASE, 60f),
        humidityVariation = preferences.getFloat(KEY_HUMIDITY_VARIATION, 5f),
        rsValue = preferences.getInt(KEY_RS_VALUE, 3),
        batValue = preferences.getInt(KEY_BAT_VALUE, 3),
        autoSendEnabled = preferences.getBoolean(KEY_AUTO_SEND_ENABLED, false),
        sendingIntervalSeconds = preferences.getInt(KEY_SENDING_INTERVAL_SECONDS, 60),
    )

    fun save(settings: AppSettings) {
        preferences.edit()
            .putFloat(KEY_TEMPERATURE_BASE, settings.temperatureBase)
            .putFloat(KEY_TEMPERATURE_VARIATION, settings.temperatureVariation)
            .putFloat(KEY_HUMIDITY_BASE, settings.humidityBase)
            .putFloat(KEY_HUMIDITY_VARIATION, settings.humidityVariation)
            .putInt(KEY_RS_VALUE, settings.rsValue)
            .putInt(KEY_BAT_VALUE, settings.batValue)
            .putBoolean(KEY_AUTO_SEND_ENABLED, settings.autoSendEnabled)
            .putInt(KEY_SENDING_INTERVAL_SECONDS, settings.sendingIntervalSeconds)
            .apply()
    }

    private companion object {
        const val PREFS_NAME = "soracom_gps_multiunit"
        const val KEY_TEMPERATURE_BASE = "temperature_base"
        const val KEY_TEMPERATURE_VARIATION = "temperature_variation"
        const val KEY_HUMIDITY_BASE = "humidity_base"
        const val KEY_HUMIDITY_VARIATION = "humidity_variation"
        const val KEY_RS_VALUE = "rs_value"
        const val KEY_BAT_VALUE = "bat_value"
        const val KEY_AUTO_SEND_ENABLED = "auto_send_enabled"
        const val KEY_SENDING_INTERVAL_SECONDS = "sending_interval_seconds"
    }
}
