import Foundation
import Combine
import CoreLocation

/// アプリの状態を管理するメインビューモデル
@MainActor
class MainViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 最後に送信したセンサーデータ
    @Published var lastSensorData: SensorData?

    /// 最後の送信日時
    @Published var lastSentAt: Date?

    /// 自動送信が有効か
    @Published var isAutoSendEnabled: Bool = false

    /// 自動送信間隔 (秒)
    @Published var sendingInterval: Int = 60

    /// GPS 位置情報を送信に含めるか
    @Published var sendLocation: Bool = true

    /// 接続ステータス
    @Published var connectionStatus: ConnectionStatus = .disconnected

    /// 最後のエラーメッセージ
    @Published var lastError: String?

    /// 送信ログ
    @Published var sendLogs: [SendLog] = []

    /// 送信中フラグ
    @Published var isSending: Bool = false

    /// LED 表示状態
    @Published var ledState: LedState = .off

    /// メタデータ取得状態
    @Published var isLoadingMetadata: Bool = false

    // MARK: - Services

    let locationService: LocationService
    let motionService: MotionService
    private let metadataService: MetadataService
    private let dataSendingService: DataSendingService
    let arcService: SoracomArcServiceProtocol
    let settings: AppSettings

    // MARK: - Private Properties

    private var autoSendTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        settings: AppSettings,
        arcService: SoracomArcServiceProtocol? = nil
    ) {
        self.settings = settings
        let arc = arcService ?? LibsoratunArcService()
        self.arcService = arc
        self.locationService = LocationService()
        self.motionService = MotionService()
        self.metadataService = MetadataService(arcService: arc)
        self.dataSendingService = DataSendingService(arcService: arc)

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Arc 設定が変更されたら再接続を試みる
        settings.$arcConfigJSON
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.reconnect()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func onAppear() {
        locationService.requestAuthorization()
        locationService.startUpdating()
        motionService.startUpdating()

        Task {
            await connectArc()
        }
    }

    func onDisappear() {
        locationService.stopUpdating()
        motionService.stopUpdating()
        stopAutoSend()
    }

    // MARK: - SORACOM Arc 接続

    /// SORACOM Arc に接続する
    func connectArc() async {
        let configJSON = settings.arcConfigJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configJSON.isEmpty else {
            connectionStatus = .disconnected
            isAutoSendEnabled = settings.defaultAutoSend
            sendingInterval = settings.defaultSendingInterval
            if settings.defaultAutoSend {
                startAutoSend()
            }
            return
        }

        connectionStatus = .connecting

        do {
            try arcService.configure(with: configJSON)
            connectionStatus = .connected
            await fetchMetadataConfig()
        } catch {
            connectionStatus = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            // フォールバック設定を使用
            isAutoSendEnabled = settings.defaultAutoSend
            sendingInterval = settings.defaultSendingInterval
            if settings.defaultAutoSend {
                startAutoSend()
            }
        }
    }

    /// Arc 再接続
    func reconnect() async {
        stopAutoSend()
        await connectArc()
    }

    // MARK: - メタデータ取得

    /// メタデータサービスから設定を取得する
    func fetchMetadataConfig() async {
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }

        do {
            let config = try await metadataService.fetchConfig()
            isAutoSendEnabled = config.autoSend
            sendingInterval = config.sendingInterval
            sendLocation = config.sendLocation

            if config.autoSend {
                startAutoSend()
            }
        } catch {
            // メタデータが取得できない場合はフォールバック設定を使用
            isAutoSendEnabled = settings.defaultAutoSend
            sendingInterval = settings.defaultSendingInterval
            if settings.defaultAutoSend {
                startAutoSend()
            }
        }
    }

    // MARK: - 自動送信

    /// 自動送信を開始する
    func startAutoSend() {
        stopAutoSend()
        let interval = TimeInterval(sendingInterval)
        autoSendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.sendData(type: .periodic)
            }
        }
    }

    /// 自動送信を停止する
    func stopAutoSend() {
        autoSendTimer?.invalidate()
        autoSendTimer = nil
    }

    /// 自動送信の有効/無効を切り替える
    func toggleAutoSend() {
        isAutoSendEnabled.toggle()
        if isAutoSendEnabled {
            startAutoSend()
        } else {
            stopAutoSend()
        }
    }

    // MARK: - データ送信

    /// 手動送信 (ボタン押下時)
    func manualSend() {
        Task {
            await sendData(type: .manual)
        }
    }

    /// センサーデータを収集して送信する
    func sendData(type: SendType) async {
        guard !isSending else { return }
        isSending = true
        defer {
            isSending = false
        }

        // 送信前の点滅シーケンス（緑1秒・消灯1秒 × 4回）
        for _ in 0..<4 {
            ledState = .blinkGreen
            try? await Task.sleep(for: .seconds(1))
            ledState = .off
            try? await Task.sleep(for: .seconds(1))
        }

        let sensorData = collectSensorData(type: type)
        lastSensorData = sensorData

        guard arcService.isConfigured else {
            let log = SendLog(timestamp: Date(), data: sensorData, success: false,
                              error: "SORACOM Arc が設定されていません")
            addLog(log)
            lastError = log.error
            // エラー表示（赤5秒 → 消灯）
            ledState = .solidRed
            try? await Task.sleep(for: .seconds(5))
            ledState = .off
            return
        }

        do {
            let response = try await dataSendingService.send(sensorData)
            let log = SendLog(timestamp: Date(), data: sensorData, success: true,
                              response: response)
            addLog(log)
            lastSentAt = Date()
            lastError = nil
            // 成功表示（緑5秒 → 消灯）
            ledState = .solidGreen
            try? await Task.sleep(for: .seconds(5))
            ledState = .off
        } catch {
            let log = SendLog(timestamp: Date(), data: sensorData, success: false,
                              error: error.localizedDescription)
            addLog(log)
            lastError = error.localizedDescription
            // エラー表示（赤5秒 → 消灯）
            ledState = .solidRed
            try? await Task.sleep(for: .seconds(5))
            ledState = .off
        }
    }

    // MARK: - センサーデータ収集

    /// 現在のセンサー値を収集してSensorDataを生成する
    private func collectSensorData(type: SendType) -> SensorData {
        let location = locationService.currentLocation
        let acceleration = motionService.acceleration

        let lat: Double?
        let lon: Double?

        if sendLocation, let loc = location {
            lat = (loc.coordinate.latitude * 10).rounded() / 10
            lon = (loc.coordinate.longitude * 10).rounded() / 10
        } else {
            lat = nil
            lon = nil
        }

        return SensorData(
            lat: lat,
            lon: lon,
            temp: generateTemperature(),
            humi: generateHumidity(),
            x: (acceleration.x * 10000).rounded() / 10,
            y: (acceleration.y * 10000).rounded() / 10,
            z: (acceleration.z * 10000).rounded() / 10,
            bat: settings.batValue,
            rs: settings.rsValue,
            type: type
        )
    }

    /// 設定ベースにランダム変動を加えた温度を生成する
    private func generateTemperature() -> Double {
        let variation = Double.random(
            in: -settings.temperatureVariation...settings.temperatureVariation
        )
        let value = settings.temperatureBase + variation
        return (value * 10).rounded() / 10
    }

    /// 設定ベースにランダム変動を加えた湿度を生成する
    private func generateHumidity() -> Double {
        let variation = Double.random(
            in: -settings.humidityVariation...settings.humidityVariation
        )
        let value = (settings.humidityBase + variation).clamped(to: 0...100)
        return (value * 10).rounded() / 10
    }

    // MARK: - Logs

    private func addLog(_ log: SendLog) {
        sendLogs.insert(log, at: 0)
        // 最大100件まで保持
        if sendLogs.count > 100 {
            sendLogs.removeLast()
        }
    }
}

// MARK: - Supporting Types

/// LED の表示状態
enum LedState: Equatable {
    /// 消灯
    case off
    /// 送信前点滅（緑）
    case blinkGreen
    /// 通信成功（緑点灯）
    case solidGreen
    /// 通信エラー（赤点灯）
    case solidRed
}

/// 接続ステータス
enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var displayText: String {
        switch self {
        case .disconnected: return "未接続"
        case .connecting: return "接続中..."
        case .connected: return "接続済み"
        case .failed: return "接続失敗"
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting: return "yellow"
        case .connected: return "green"
        case .failed: return "red"
        }
    }
}

/// 送信ログエントリ
struct SendLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let data: SensorData
    let success: Bool
    let response: String?
    let error: String?

    init(timestamp: Date, data: SensorData, success: Bool, response: String? = nil, error: String? = nil) {
        self.timestamp = timestamp
        self.data = data
        self.success = success
        self.response = response
        self.error = error
    }
}

// MARK: - Comparable extensions

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
