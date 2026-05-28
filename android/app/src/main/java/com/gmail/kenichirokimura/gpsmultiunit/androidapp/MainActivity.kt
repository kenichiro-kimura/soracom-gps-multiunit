package com.gmail.kenichirokimura.gpsmultiunit.androidapp

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.DataUsage
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.List
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.gmail.kenichirokimura.gpsmultiunit.androidapp.ui.theme.SoracomGPSMultiunitTheme

class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SoracomGPSMultiunitTheme {
                val uiState by viewModel.uiState.collectAsStateWithLifecycle()
                val permissionLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.RequestMultiplePermissions(),
                ) { result ->
                    viewModel.onLocationPermissionChanged(result.values.any { it })
                }

                LaunchedEffect(Unit) {
                    permissionLauncher.launch(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                        )
                    )
                }

                App(uiState = uiState, onManualSend = viewModel::manualSend, onUpdateSettings = viewModel::updateSettings, onClearLogs = viewModel::clearLogs)
            }
        }
    }

    override fun onStart() {
        super.onStart()
        viewModel.onStart()
    }

    override fun onStop() {
        viewModel.onStop()
        super.onStop()
    }
}

private enum class AppTab {
    DEVICE,
    LOGS,
    SETTINGS,
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun App(
    uiState: MainUiState,
    onManualSend: () -> Unit,
    onUpdateSettings: (AppSettings) -> Unit,
    onClearLogs: () -> Unit,
) {
    var currentTab by remember { mutableStateOf(AppTab.DEVICE) }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Soracom GPS Multiunit") })
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = currentTab == AppTab.DEVICE,
                    onClick = { currentTab = AppTab.DEVICE },
                    icon = { Icon(Icons.Default.DataUsage, contentDescription = null) },
                    label = { Text("デバイス") },
                )
                NavigationBarItem(
                    selected = currentTab == AppTab.LOGS,
                    onClick = { currentTab = AppTab.LOGS },
                    icon = { Icon(Icons.Outlined.List, contentDescription = null) },
                    label = { Text("ログ") },
                )
                NavigationBarItem(
                    selected = currentTab == AppTab.SETTINGS,
                    onClick = { currentTab = AppTab.SETTINGS },
                    icon = { Icon(Icons.Default.Settings, contentDescription = null) },
                    label = { Text("設定") },
                )
            }
        },
    ) { innerPadding ->
        Surface(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            when (currentTab) {
                AppTab.DEVICE -> DeviceTab(uiState = uiState, onManualSend = onManualSend)
                AppTab.LOGS -> LogsTab(uiState = uiState, onClearLogs = onClearLogs)
                AppTab.SETTINGS -> SettingsTab(settings = uiState.settings, onUpdateSettings = onUpdateSettings)
            }
        }
    }
}

@Composable
private fun DeviceTab(uiState: MainUiState, onManualSend: () -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item { Spacer(modifier = Modifier.height(8.dp)) }
        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = SoracomTeal),
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.fillMaxWidth().padding(20.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(16.dp)
                                .clip(CircleShape)
                                .background(statusColor(uiState.connectionStatus))
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(connectionStatusLabel(uiState.connectionStatus), color = Color.White, fontWeight = FontWeight.SemiBold)
                        Spacer(modifier = Modifier.weight(1f))
                        Image(
                            painter = painterResource(R.drawable.soracom_ug_logo),
                            contentDescription = "SORACOM UG logo",
                            modifier = Modifier.width(72.dp),
                            contentScale = ContentScale.Fit,
                        )
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                    Button(onClick = onManualSend, enabled = !uiState.isSending) {
                        Icon(Icons.Default.ArrowUpward, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if (uiState.isSending) "送信中..." else "手動送信")
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = uiState.lastSentAtLabel?.let { "最終送信: $it" } ?: "まだ送信していません",
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    if (!uiState.locationPermissionGranted) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.LocationOff, contentDescription = null, tint = Color.White)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("位置情報権限がないため GPS は未設定です", color = Color.White)
                        }
                    }
                }
            }
        }
        item {
            SensorSummary(uiState)
        }
        uiState.lastError?.let { error ->
            item {
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                    Text(error, modifier = Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                }
            }
        }
        item { Spacer(modifier = Modifier.height(8.dp)) }
    }
}

@Composable
private fun SensorSummary(uiState: MainUiState) {
    Card(shape = RoundedCornerShape(20.dp)) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("最新センサー値", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Divider()
            val sensorData = uiState.lastSensorData
            SensorRow("温度", sensorData?.temp?.let { "%.1f°C".format(it) } ?: "未送信")
            SensorRow("湿度", sensorData?.humi?.let { "%.1f%%".format(it) } ?: "未送信")
            SensorRow(
                "加速度",
                sensorData?.let { "X %.1f / Y %.1f / Z %.1f mG".format(it.x ?: 0.0, it.y ?: 0.0, it.z ?: 0.0) } ?: "未送信",
            )
            SensorRow(
                "GPS",
                sensorData?.lat?.let { lat -> "%.6f, %.6f".format(lat, sensorData.lon ?: 0.0) } ?: "信号なし",
            )
            SensorRow("電波強度", sensorData?.rs?.toString() ?: uiState.settings.rsValue.toString())
            SensorRow("バッテリー", sensorData?.bat?.toString() ?: uiState.settings.batValue.toString())
            AssistChip(onClick = {}, label = {
                Text(if (uiState.settings.autoSendEnabled) "自動送信: ${uiState.settings.sendingIntervalSeconds}秒" else "手動送信")
            })
        }
    }
}

@Composable
private fun SensorRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.width(80.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun LogsTab(uiState: MainUiState, onClearLogs: () -> Unit) {
    if (uiState.sendLogs.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("送信ログはまだありません")
        }
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Row(modifier = Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.End) {
                FilterChip(selected = false, onClick = onClearLogs, label = { Text("ログを消去") })
            }
        }
        items(uiState.sendLogs) { log ->
            var expanded by remember(log.timestampLabel) { mutableStateOf(false) }
            Card(shape = RoundedCornerShape(16.dp)) {
                Column(modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded }.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(modifier = Modifier.size(10.dp).clip(CircleShape).background(if (log.success) Color(0xFF2E7D32) else MaterialTheme.colorScheme.error))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(log.timestampLabel, fontWeight = FontWeight.SemiBold)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(log.message, color = if (log.success) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.error)
                    if (expanded) {
                        Spacer(modifier = Modifier.height(12.dp))
                        Divider()
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(log.sensorData.toJsonString(), style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsTab(settings: AppSettings, onUpdateSettings: (AppSettings) -> Unit) {
    var currentSettings by remember(settings) { mutableStateOf(settings) }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        SettingsSliderCard(
            title = "温度ベース値",
            valueText = "%.1f°C".format(currentSettings.temperatureBase),
            value = currentSettings.temperatureBase,
            range = -40f..85f,
            steps = 249,
        ) {
            currentSettings = currentSettings.copy(temperatureBase = it)
            onUpdateSettings(currentSettings)
        }
        SettingsSliderCard(
            title = "温度変動幅",
            valueText = "±%.1f°C".format(currentSettings.temperatureVariation),
            value = currentSettings.temperatureVariation,
            range = 0f..10f,
            steps = 19,
        ) {
            currentSettings = currentSettings.copy(temperatureVariation = it)
            onUpdateSettings(currentSettings)
        }
        SettingsSliderCard(
            title = "湿度ベース値",
            valueText = "%.1f%%".format(currentSettings.humidityBase),
            value = currentSettings.humidityBase,
            range = 0f..100f,
            steps = 99,
        ) {
            currentSettings = currentSettings.copy(humidityBase = it)
            onUpdateSettings(currentSettings)
        }
        SettingsSliderCard(
            title = "湿度変動幅",
            valueText = "±%.1f%%".format(currentSettings.humidityVariation),
            value = currentSettings.humidityVariation,
            range = 0f..20f,
            steps = 19,
        ) {
            currentSettings = currentSettings.copy(humidityVariation = it)
            onUpdateSettings(currentSettings)
        }
        StepperCard(title = "電波強度 (rs)", value = currentSettings.rsValue, range = -1..4) {
            currentSettings = currentSettings.copy(rsValue = it)
            onUpdateSettings(currentSettings)
        }
        StepperCard(title = "バッテリー (bat)", value = currentSettings.batValue, range = -1..3) {
            currentSettings = currentSettings.copy(batValue = it)
            onUpdateSettings(currentSettings)
        }
        Card(shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("自動送信")
                        Text("UDP 送信を設定秒数で繰り返します", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Switch(
                        checked = currentSettings.autoSendEnabled,
                        onCheckedChange = {
                            currentSettings = currentSettings.copy(autoSendEnabled = it)
                            onUpdateSettings(currentSettings)
                        },
                    )
                }
                if (currentSettings.autoSendEnabled) {
                    SettingsSliderCard(
                        title = "送信間隔",
                        valueText = "${currentSettings.sendingIntervalSeconds}秒",
                        value = currentSettings.sendingIntervalSeconds.toFloat(),
                        range = 5f..3600f,
                        steps = 718,
                    ) {
                        currentSettings = currentSettings.copy(sendingIntervalSeconds = it.toInt().coerceAtLeast(5))
                        onUpdateSettings(currentSettings)
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsSliderCard(
    title: String,
    valueText: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    onValueChange: (Float) -> Unit,
) {
    Card(shape = RoundedCornerShape(16.dp)) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(valueText, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Slider(value = value, onValueChange = onValueChange, valueRange = range, steps = steps)
        }
    }
}

@Composable
private fun StepperCard(title: String, value: Int, range: IntRange, onValueChange: (Int) -> Unit) {
    Card(shape = RoundedCornerShape(16.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Row(verticalAlignment = Alignment.CenterVertically) {
                SmallActionButton(text = "-", enabled = value > range.first) { onValueChange(value - 1) }
                Spacer(modifier = Modifier.width(12.dp))
                Text(value.toString(), fontWeight = FontWeight.Medium)
                Spacer(modifier = Modifier.width(12.dp))
                SmallActionButton(text = "+", enabled = value < range.last) { onValueChange(value + 1) }
            }
        }
    }
}

@Composable
private fun SmallActionButton(text: String, enabled: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.size(32.dp).clip(CircleShape).clickable(enabled = enabled, onClick = onClick),
        color = if (enabled) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
        shape = CircleShape,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(text, color = MaterialTheme.colorScheme.onPrimaryContainer, fontWeight = FontWeight.Bold)
        }
    }
}

private fun connectionStatusLabel(status: ConnectionStatus): String = when (status) {
    ConnectionStatus.DISCONNECTED -> "送信待機"
    ConnectionStatus.SENDING -> "送信中"
    ConnectionStatus.CONNECTED -> "UDP 送信成功"
    ConnectionStatus.FAILED -> "送信失敗"
}

private fun statusColor(status: ConnectionStatus): Color = when (status) {
    ConnectionStatus.DISCONNECTED -> Color.LightGray
    ConnectionStatus.SENDING -> Color(0xFFFFD54F)
    ConnectionStatus.CONNECTED -> Color(0xFF66BB6A)
    ConnectionStatus.FAILED -> Color(0xFFEF5350)
}

private val SoracomTeal = Color(0xFF4FD9D9)
