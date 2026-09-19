package org.sokohiki.kimura.app.soracom.gpsmultiunit

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.sokohiki.kimura.app.soracom.gpsmultiunit.ui.theme.SoracomGPSMultiunitTheme

class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
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
            TopAppBar(title = { Text("GPSトラッカーシミュレーター") })
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
private fun DeviceTab(
    uiState: MainUiState,
    onManualSend: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { Spacer(modifier = Modifier.height(10.dp)) }
        item {
            DeviceCard(uiState = uiState, onManualSend = onManualSend)
        }
        item {
            StatusCard(uiState = uiState, onManualSend = onManualSend)
        }
        uiState.lastError?.let { error ->
            item {
                Card(
                    shape = RoundedCornerShape(14.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                ) {
                    Text(error, modifier = Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                }
            }
        }
        item { Spacer(modifier = Modifier.height(8.dp)) }
    }
}

@Composable
private fun DeviceCard(uiState: MainUiState, onManualSend: () -> Unit) {
    val ledColor = when (uiState.ledState) {
        LedState.OFF -> Color(0xFF1A1A1A)
        LedState.BLINK_GREEN, LedState.SOLID_GREEN -> Color(0xFF66BB6A)
        LedState.SOLID_RED -> Color(0xFFEF5350)
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(202.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(modifier = Modifier.size(width = 320.dp, height = 202.dp)) {
            Image(
                painter = painterResource(R.drawable.device_background),
                contentDescription = "GPSトラッカー本体",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.FillBounds,
            )
            Column(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(width = 20.dp, height = 14.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(Color.White)
                        .padding(3.dp)
                        .background(ledColor, RoundedCornerShape(2.dp)),
                )
                Button(
                    onClick = onManualSend,
                    enabled = !uiState.isSending,
                    modifier = Modifier.size(42.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF141414),
                        contentColor = Color(0xFFC0C0C0),
                    ),
                ) {
                    Box(
                        modifier = Modifier
                            .size(25.dp)
                            .border(1.dp, Color(0xFF8A8A8A), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Default.ArrowUpward, contentDescription = "手動送信", modifier = Modifier.size(18.dp))
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    repeat(2) {
                        Box(
                            modifier = Modifier
                                .size(width = 34.dp, height = 11.dp)
                                .clip(RoundedCornerShape(3.dp))
                                .background(Color(0xFF1F1F1F)),
                        )
                    }
                }
            }
            Image(
                painter = painterResource(R.drawable.soracom_ug_logo),
                contentDescription = "SORACOM UG logo",
                modifier = Modifier.align(Alignment.BottomStart).padding(start = 12.dp, bottom = 10.dp).size(72.dp),
                contentScale = ContentScale.Fit,
            )
        }
    }
}

@Composable
private fun StatusCard(uiState: MainUiState, onManualSend: () -> Unit) {
    val sensorData = uiState.lastSensorData
    val connected = uiState.connectionStatus == ConnectionStatus.CONNECTED

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFF7F7F7)),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("ステータス", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.weight(1f))
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = if (connected) Color(0xFFDFF5DF) else Color(0xFFE9E9E9),
                ) {
                    Text(
                        text = connectionStatusLabel(uiState.connectionStatus),
                        modifier = Modifier.padding(horizontal = 9.dp, vertical = 4.dp),
                        color = if (connected) Color(0xFF3D9A4A) else Color(0xFF757575),
                        style = MaterialTheme.typography.labelSmall,
                    )
                }
            }
            Row(
                modifier = Modifier.fillMaxWidth().clickable(enabled = !uiState.isSending, onClick = onManualSend),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    Icons.Default.ArrowUpward,
                    contentDescription = "手動送信",
                    modifier = Modifier.size(18.dp),
                    tint = SoracomTeal,
                )
                Spacer(modifier = Modifier.width(8.dp))
                Column {
                    Text(
                        sendStatusLabel(sensorData?.type, uiState.isSending),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        "最終送信: ${uiState.lastSentAtLabel ?: "未送信"}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            HorizontalDivider(color = Color(0xFFD6D6D6))
            Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                StatusValue(
                    label = "温度",
                    value = sensorData?.temp?.let { "%.1f°C".format(it) } ?: "--",
                    modifier = Modifier.weight(1f),
                )
                StatusValue(
                    label = "湿度",
                    value = sensorData?.humi?.let { "%.1f%%".format(it) } ?: "--",
                    modifier = Modifier.weight(1f),
                )
            }
            StatusValue(
                label = "加速度",
                value = sensorData?.let { "X:%.1f  Y:%.1f  Z:%.1f mG".format(it.x ?: 0.0, it.y ?: 0.0, it.z ?: 0.0) } ?: "--",
            )
            StatusValue(
                label = "GPS",
                value = sensorData?.lat?.let { lat -> "%.6f, %.6f".format(lat, sensorData.lon ?: 0.0) } ?: "信号なし",
            )
        }
    }
}

@Composable
private fun StatusValue(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = SoracomTeal)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
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
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("送信ログ", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.weight(1f))
                FilterChip(selected = false, onClick = onClearLogs, label = { Text("消去") })
            }
        }
        items(uiState.sendLogs) { log ->
            Card(
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(16.dp)
                                .clip(CircleShape)
                                .background(if (log.success) Color(0xFF5ABB68) else MaterialTheme.colorScheme.error),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(if (log.success) "✓" else "!", color = Color.White, style = MaterialTheme.typography.labelSmall)
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(log.timestampLabel.replace("T", " "), fontWeight = FontWeight.SemiBold)
                        Spacer(modifier = Modifier.weight(1f))
                        Surface(shape = RoundedCornerShape(10.dp), color = Color(0xFFF0F0F2)) {
                            Text(
                                sendTypeLabel(log.sensorData.type),
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                style = MaterialTheme.typography.labelSmall,
                            )
                        }
                    }
                    Text(
                        if (log.success) "センサー値を送信しました" else log.message,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (log.success) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.error,
                    )
                    LogSensorPanel(log.sensorData)
                }
            }
        }
    }
}

@Composable
private fun LogSensorPanel(sensorData: SensorData) {
    Surface(
        modifier = Modifier.width(220.dp),
        shape = RoundedCornerShape(8.dp),
        color = Color(0xFFF2F2F6),
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            Row {
                LogMetric("温度", sensorData.temp?.let { "%.1f°C".format(it) } ?: "--", Modifier.weight(1f))
                LogMetric("湿度", sensorData.humi?.let { "%.1f%%".format(it) } ?: "--", Modifier.weight(1f))
            }
            Row {
                LogMetric("X", sensorData.x?.let { "%.0f mG".format(it) } ?: "--", Modifier.weight(1f))
                LogMetric("Y", sensorData.y?.let { "%.0f mG".format(it) } ?: "--", Modifier.weight(1f))
                LogMetric("Z", sensorData.z?.let { "%.0f mG".format(it) } ?: "--", Modifier.weight(1f))
            }
            Row {
                LogMetric("緯度", sensorData.lat?.let { "%.6f".format(it) } ?: "--", Modifier.weight(1f))
                LogMetric("経度", sensorData.lon?.let { "%.6f".format(it) } ?: "--", Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun LogMetric(label: String, value: String, modifier: Modifier) {
    Column(modifier = modifier) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        Text(value, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
    }
}

private fun sendTypeLabel(type: SendType): String = when (type) {
    SendType.MANUAL -> "手動"
    SendType.PERIODIC -> "定期"
    SendType.ACCELERATION_ALERT -> "加速度"
}

private fun sendStatusLabel(type: SendType?, isSending: Boolean): String {
    val label = when (type) {
        SendType.PERIODIC -> "自動送信"
        SendType.MANUAL, null -> "手動送信"
        SendType.ACCELERATION_ALERT -> "加速度送信"
    }
    return if (isSending) "${label}中…" else label
}

@Composable
private fun SettingsTab(settings: AppSettings, onUpdateSettings: (AppSettings) -> Unit) {
    var currentSettings by remember(settings) { mutableStateOf(settings) }
    var arcConfigInput by remember(settings.arcConfig) { mutableStateOf(settings.arcConfig) }
    val uriHandler = LocalUriHandler.current

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        SettingsSliderCard(
            title = "温度設定",
            valueText = "ベース温度: %.1f °C".format(currentSettings.temperatureBase),
            value = currentSettings.temperatureBase,
            range = -40f..85f,
            steps = 249,
        ) {
            currentSettings = currentSettings.copy(temperatureBase = it)
            onUpdateSettings(currentSettings)
        }
        SettingsSliderCard(
            title = "温度設定",
            valueText = "変動幅: ± %.1f °C".format(currentSettings.temperatureVariation),
            value = currentSettings.temperatureVariation,
            range = 0f..10f,
            steps = 19,
        ) {
            currentSettings = currentSettings.copy(temperatureVariation = it)
            onUpdateSettings(currentSettings)
        }
        SettingsSliderCard(
            title = "湿度設定",
            valueText = "ベース湿度: %.1f %%".format(currentSettings.humidityBase),
            value = currentSettings.humidityBase,
            range = 0f..100f,
            steps = 99,
        ) {
            currentSettings = currentSettings.copy(humidityBase = it)
            onUpdateSettings(currentSettings)
        }
        SettingsSliderCard(
            title = "湿度設定",
            valueText = "変動幅: ± %.1f %%".format(currentSettings.humidityVariation),
            value = currentSettings.humidityVariation,
            range = 0f..20f,
            steps = 19,
        ) {
            currentSettings = currentSettings.copy(humidityVariation = it)
            onUpdateSettings(currentSettings)
        }
        StepperCard(
            title = "電波強度 (rs): ${if (currentSettings.rsValue == -1) "圏外" else currentSettings.rsValue}",
            value = currentSettings.rsValue,
            range = -1..4,
        ) {
            currentSettings = currentSettings.copy(rsValue = it)
            onUpdateSettings(currentSettings)
        }
        StepperCard(
            title = "バッテリー (bat): ${if (currentSettings.batValue == -1) "充電中" else currentSettings.batValue}",
            value = currentSettings.batValue,
            range = -1..3,
        ) {
            currentSettings = currentSettings.copy(batValue = it)
            onUpdateSettings(currentSettings)
        }
        Card(shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("固定位置情報送信")
                        Text(
                            "オンにすると、実際の位置情報の代わりに東京駅（35.681236, 139.767125）の固定位置を送信します。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = currentSettings.useFixedLocation,
                        onCheckedChange = {
                            currentSettings = currentSettings.copy(useFixedLocation = it)
                            onUpdateSettings(currentSettings)
                        },
                    )
                }
            }
        }
        Card(shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("SORACOM Arc 設定", fontWeight = FontWeight.SemiBold)
                Text(
                    "SORACOM コンソールの SIM 管理 > SIM 詳細 > バーチャル SIM から WireGuard 接続情報を取得して貼り付けてください。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = arcConfigInput,
                    onValueChange = { arcConfigInput = it },
                    modifier = Modifier.fillMaxWidth().height(180.dp),
                    label = { Text("WireGuard 設定") },
                )
                Button(
                    onClick = {
                        currentSettings = currentSettings.copy(arcConfig = arcConfigInput)
                        onUpdateSettings(currentSettings)
                    },
                    enabled = arcConfigInput != settings.arcConfig,
                    modifier = Modifier.align(Alignment.End),
                ) {
                    Text("ARC 設定を保存")
                }
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("インターネット経由 UDP にフォールバック")
                        Text(
                            "Arc 設定が未入力・無効、または SORACOM Arc で通信できない場合に uni.soracom.io へ UDP 送信します。OFF の場合は送信に失敗します。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = currentSettings.arcUdpFallbackEnabled,
                        onCheckedChange = {
                            currentSettings = currentSettings.copy(arcUdpFallbackEnabled = it)
                            onUpdateSettings(currentSettings)
                        },
                    )
                }
            }
        }
        Card(shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("自動送信")
                        Text(
                            "指定した間隔でセンサーデータを自動送信します。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
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
                        title = "自動送信設定",
                        valueText = "送信間隔: ${currentSettings.sendingIntervalSeconds} 秒",
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
        Card(shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("アプリについて", fontWeight = FontWeight.SemiBold)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("バージョン")
                    Text("1.0", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("ビルド")
                    Text("1", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(
                    "GitHub リポジトリ",
                    modifier = Modifier.clickable {
                        uriHandler.openUri("https://github.com/kenichiro-kimura/soracom-gps-multiunit")
                    },
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
        Card(shape = RoundedCornerShape(16.dp)) {
            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("ライセンス", fontWeight = FontWeight.SemiBold)
                Text("SORACOM UGロゴを使用しています。", style = MaterialTheme.typography.bodySmall)
                Text(
                    "ロゴの配布元",
                    modifier = Modifier.clickable { uriHandler.openUri("https://github.com/soracomug/logo") },
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    "CC BY 4.0 ライセンス",
                    modifier = Modifier.clickable { uriHandler.openUri("https://creativecommons.org/licenses/by/4.0/") },
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.bodySmall,
                )
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
    ConnectionStatus.CONNECTED -> "送信成功"
    ConnectionStatus.FAILED -> "送信失敗"
}

private fun statusColor(status: ConnectionStatus): Color = when (status) {
    ConnectionStatus.DISCONNECTED -> Color.LightGray
    ConnectionStatus.SENDING -> Color(0xFFFFD54F)
    ConnectionStatus.CONNECTED -> Color(0xFF66BB6A)
    ConnectionStatus.FAILED -> Color(0xFFEF5350)
}

private val SoracomTeal = Color(0xFF4FD9D9)
