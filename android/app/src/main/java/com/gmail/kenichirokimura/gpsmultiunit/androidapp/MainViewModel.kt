package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import android.Manifest
import android.app.Application
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.round

class MainViewModel(application: Application) : AndroidViewModel(application) {
    private val settingsRepository = SettingsRepository(application)
    private val udpSendingService = UdpSendingService()
    private val locationManager = application.getSystemService(LocationManager::class.java)
    private val sensorManager = application.getSystemService(SensorManager::class.java)

    private val _uiState = MutableStateFlow(MainUiState(settings = settingsRepository.load()))
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    private var lastLocation: Location? = null
    private var lastAcceleration = Triple(0.0, 0.0, 0.0)
    private var autoSendJob: Job? = null

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            lastLocation = location
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
    }

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor.type != Sensor.TYPE_ACCELEROMETER) return
            lastAcceleration = Triple(
                metersPerSecondSquaredToMilliG(event.values[0]),
                metersPerSecondSquaredToMilliG(event.values[1]),
                metersPerSecondSquaredToMilliG(event.values[2]),
            )
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    init {
        updateLocationPermissionState()
        if (_uiState.value.locationPermissionGranted) {
            startSensors()
        }
        restartAutoSendIfNeeded()
    }

    fun onStart() {
        if (_uiState.value.locationPermissionGranted) {
            startSensors()
        }
    }

    fun onStop() {
        stopSensors()
    }

    fun onLocationPermissionChanged(granted: Boolean) {
        _uiState.update {
            it.copy(
                locationPermissionGranted = granted,
                lastError = if (granted) null else "位置情報の権限がないため GPS 値は送信されません。",
            )
        }
        if (granted) {
            startSensors()
        } else {
            stopSensors()
        }
    }

    fun updateSettings(settings: AppSettings) {
        settingsRepository.save(settings)
        _uiState.update { it.copy(settings = settings) }
        restartAutoSendIfNeeded()
    }

    fun clearLogs() {
        _uiState.update { it.copy(sendLogs = emptyList()) }
    }

    fun manualSend() {
        sendData(SendType.MANUAL)
    }

    private fun updateLocationPermissionState() {
        val granted = hasLocationPermission()
        _uiState.update { it.copy(locationPermissionGranted = granted) }
        if (!granted) {
            _uiState.update { it.copy(lastError = "位置情報の権限がないため GPS 値は送信されません。") }
        }
    }

    private fun startSensors() {
        if (!hasLocationPermission()) return
        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                1_000L,
                0f,
                locationListener,
            )
            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                1_000L,
                0f,
                locationListener,
            )
        } catch (_: SecurityException) {
            _uiState.update { it.copy(lastError = "位置情報の利用許可を確認できませんでした。") }
        } catch (_: IllegalArgumentException) {
            // Provider がない場合は無視する。
        }

        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sensor ->
            sensorManager.registerListener(sensorListener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun stopSensors() {
        sensorManager.unregisterListener(sensorListener)
        runCatching { locationManager.removeUpdates(locationListener) }
    }

    private fun restartAutoSendIfNeeded() {
        autoSendJob?.cancel()
        val settings = _uiState.value.settings
        if (!settings.autoSendEnabled) return

        autoSendJob = viewModelScope.launch {
            while (true) {
                delay(settings.sendingIntervalSeconds * 1_000L)
                sendData(SendType.PERIODIC)
            }
        }
    }

    private fun sendData(type: SendType) {
        if (_uiState.value.isSending) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSending = true, connectionStatus = ConnectionStatus.SENDING) }
            val sensorData = collectSensorData(type)
            _uiState.update { it.copy(lastSensorData = sensorData) }

            runCatching {
                udpSendingService.send(sensorData.toJsonString())
            }.onSuccess { response ->
                val log = SendLog(sensorData = sensorData, success = true, message = response)
                _uiState.update {
                    it.copy(
                        isSending = false,
                        connectionStatus = ConnectionStatus.CONNECTED,
                        lastSensorData = sensorData,
                        lastError = null,
                        lastSentAtLabel = java.time.LocalTime.now().withNano(0).toString(),
                        sendLogs = listOf(log) + it.sendLogs.take(99),
                    )
                }
            }.onFailure { error ->
                val log = SendLog(sensorData = sensorData, success = false, message = error.localizedMessage ?: "送信に失敗しました。")
                _uiState.update {
                    it.copy(
                        isSending = false,
                        connectionStatus = ConnectionStatus.FAILED,
                        lastSensorData = sensorData,
                        lastError = log.message,
                        sendLogs = listOf(log) + it.sendLogs.take(99),
                    )
                }
            }
        }
    }

    private fun collectSensorData(type: SendType): SensorData {
        val settings = _uiState.value.settings
        val location = lastLocation.takeIf { _uiState.value.locationPermissionGranted }
        val (x, y, z) = lastAcceleration

        return SensorData(
            lat = location?.latitude?.roundedTo(6),
            lon = location?.longitude?.roundedTo(6),
            temp = SensorValueGenerator.temperature(settings),
            humi = SensorValueGenerator.humidity(settings),
            x = x,
            y = y,
            z = z,
            bat = settings.batValue,
            rs = settings.rsValue,
            type = type,
        )
    }

    private fun hasLocationPermission(): Boolean {
        val context = getApplication<Application>()
        return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun metersPerSecondSquaredToMilliG(value: Float): Double {
        val milliG = value / SensorManager.GRAVITY_EARTH * 1000.0
        return round(milliG * 10.0) / 10.0
    }
}

data class MainUiState(
    val settings: AppSettings,
    val locationPermissionGranted: Boolean = false,
    val connectionStatus: ConnectionStatus = ConnectionStatus.DISCONNECTED,
    val isSending: Boolean = false,
    val lastError: String? = null,
    val lastSensorData: SensorData? = null,
    val lastSentAtLabel: String? = null,
    val sendLogs: List<SendLog> = emptyList(),
)

enum class ConnectionStatus {
    DISCONNECTED,
    SENDING,
    CONNECTED,
    FAILED,
}

data class SendLog(
    val sensorData: SensorData,
    val success: Boolean,
    val message: String,
    val timestampLabel: String = java.time.LocalDateTime.now().withNano(0).toString(),
)

private fun Double.roundedTo(scale: Int): Double {
    val multiplier = Math.pow(10.0, scale.toDouble())
    return round(this * multiplier) / multiplier
}
