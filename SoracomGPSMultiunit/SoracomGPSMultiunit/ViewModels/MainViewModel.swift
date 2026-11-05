import Foundation
import Combine
import CoreLocation

/// アプリの状態を管理するメインビューモデル
@MainActor
class MainViewModel: ObservableObject {

    private static let fixedLocation = CLLocationCoordinate2D(
        latitude: 35.681236,
        longitude: 139.767125
    )

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

    /// 温度を送信に含めるか
    @Published var sendTemperature: Bool = true

    /// 湿度を送信に含めるか
    @Published var sendHumidity: Bool = true

    /// 加速度データを送信に含めるか
    @Published var sendAcceleration: Bool = true

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
    private let ledDelay: TimeInterval

    // MARK: - Init

    init(
        settings: AppSettings,
        arcService: SoracomArcServiceProtocol? = nil,
        ledDelay: TimeInterval = 1.0
    ) {
        self.settings = settings
        self.ledDelay = ledDelay
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

        // 固定位置モードが変更されたら、実 GPS の取得も切り替える
        settings.$useFixedLocation
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateLocationUpdates()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func onAppear() {
        updateLocationUpdates()
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

    private func updateLocationUpdates() {
        if settings.useFixedLocation {
            locationService.stopUpdating()
        } else {
            locationService.requestAuthorization()
            locationService.startUpdating()
        }
    }

    // MARK: - SORACOM Arc 接続

    /// SORACOM Arc に接続する
    func connectArc() async {
        let configJSON = settings.arcConfigJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configJSON.isEmpty else {
            connectionStatus = .disconnected
            isAutoSendEnabled = settings.defaultAutoSend
            sendingInterval = settings.defaultSendingInterval
            sendLocation = true
            sendTemperature = true
            sendHumidity = true
            sendAcceleration = true
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
            sendLocation = true
            sendTemperature = true
            sendHumidity = true
            sendAcceleration = true
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
            if let interval = config.sendingIntervalSeconds {
                sendingInterval = interval
            }
            sendLocation = config.sendLocation
            sendTemperature = config.sendTemperature
            sendHumidity = config.sendHumidity
            sendAcceleration = config.sendAcceleration

            if config.autoSend {
                startAutoSend()
            }
        } catch {
            // メタデータが取得できない場合はフォールバック設定を使用
            isAutoSendEnabled = settings.defaultAutoSend
            sendingInterval = settings.defaultSendingInterval
            sendLocation = true
            sendTemperature = true
            sendHumidity = true
            sendAcceleration = true
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

        let sensorData = collectSensorData(type: type)
        lastSensorData = sensorData

        // 通信と点滅シーケンスを並行して開始
        async let sendResultTask = performSend(sensorData)

        // 送信中の点滅シーケンス（緑1秒・消灯1秒 × 4回）
        for _ in 0..<4 {
            ledState = .blinkGreen
            try? await Task.sleep(for: .seconds(ledDelay))
            ledState = .off
            try? await Task.sleep(for: .seconds(ledDelay))
        }

        // 点滅完了後、通信結果に応じて LED を更新
        let result = await sendResultTask
        switch result {
        case .success(let response):
            let log = SendLog(timestamp: Date(), data: sensorData, success: true,
                              response: response)
            addLog(log)
            lastSentAt = Date()
            lastError = nil
            // 成功表示（緑5秒 → 消灯）
            ledState = .solidGreen
            try? await Task.sleep(for: .seconds(ledDelay > 0 ? 5 : 0))
            ledState = .off
        case .failure(let error):
            let log = SendLog(timestamp: Date(), data: sensorData, success: false,
                              error: error.localizedDescription)
            addLog(log)
            lastError = error.localizedDescription
            // エラー表示（赤5秒 → 消灯）
            ledState = .solidRed
            try? await Task.sleep(for: .seconds(ledDelay > 0 ? 5 : 0))
            ledState = .off
        }
    }

    /// 送信処理を Result で包んで返す（点滅シーケンスとの並行実行用）
    private func performSend(_ sensorData: SensorData) async -> Result<String, Error> {
        do {
            let response = try await dataSendingService.send(
                sensorData,
                allowUdpFallback: settings.arcUdpFallbackEnabled
            )
            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - センサーデータ収集

    /// 現在のセンサー値を収集してSensorDataを生成する
    private func collectSensorData(type: SendType) -> SensorData {
        let location = locationService.currentLocation
        let acceleration = motionService.acceleration

        let lat: Double?
        let lon: Double?

        if sendLocation, settings.useFixedLocation {
            lat = Self.fixedLocation.latitude
            lon = Self.fixedLocation.longitude
        } else if sendLocation, let loc = location {
            lat = (loc.coordinate.latitude * 1_000_000).rounded() / 1_000_000
            lon = (loc.coordinate.longitude * 1_000_000).rounded() / 1_000_000
        } else {
            lat = nil
            lon = nil
        }

        return SensorData(
            lat: lat,
            lon: lon,
            temp: sendTemperature ? generateTemperature() : nil,
            humi: sendHumidity ? generateHumidity() : nil,
            x: sendAcceleration ? (acceleration.x * 10000).rounded() / 10 : nil,
            y: sendAcceleration ? (acceleration.y * 10000).rounded() / 10 : nil,
            z: sendAcceleration ? (acceleration.z * 10000).rounded() / 10 : nil,
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
        let value = Swift.min(Swift.max(settings.humidityBase + variation, 0), 100)
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
        case .disconnected: return MessageI18n.connectionDisconnected()
        case .connecting: return MessageI18n.connectionConnecting()
        case .connected: return MessageI18n.connectionConnected()
        case .failed: return MessageI18n.connectionFailed()
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

enum MessageI18n {
    private enum Language {
        case ja
        case en
        case de
        case es
        case it
        case fr
        case ko
        case zh
    }

    private static func language(for locale: Locale = .current) -> Language {
        let code = locale.language.languageCode?.identifier ?? locale.identifier.lowercased()
        switch code {
        case "en": return .en
        case "de": return .de
        case "es": return .es
        case "it": return .it
        case "fr": return .fr
        case "ko": return .ko
        case "zh": return .zh
        default: return .ja
        }
    }

    static func appTitle(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "GPS Tracker Simulator"
        case .de: return "GPS-Tracker-Simulator"
        case .es: return "Simulador de rastreador GPS"
        case .it: return "Simulatore tracker GPS"
        case .fr: return "Simulateur de traceur GPS"
        case .ko: return "GPS 트래커 시뮬레이터"
        case .zh: return "GPS 跟踪器模拟器"
        case .ja: return "GPSトラッカーシミュレーター"
        }
    }

    static func tabDevice(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Device"
        case .de: return "Gerät"
        case .es: return "Dispositivo"
        case .it: return "Dispositivo"
        case .fr: return "Appareil"
        case .ko: return "디바이스"
        case .zh: return "设备"
        case .ja: return "デバイス"
        }
    }

    static func tabLog(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Logs"
        case .de: return "Protokoll"
        case .es: return "Registro"
        case .it: return "Log"
        case .fr: return "Journaux"
        case .ko: return "로그"
        case .zh: return "日志"
        case .ja: return "ログ"
        }
    }

    static func statusTitle(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Status"
        case .de: return "Status"
        case .es: return "Estado"
        case .it: return "Stato"
        case .fr: return "Statut"
        case .ko: return "상태"
        case .zh: return "状态"
        case .ja: return "ステータス"
        }
    }

    static func autoSendLabel(interval: Int, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Auto send: every \(interval)s"
        case .de: return "Automatisches Senden: alle \(interval)s"
        case .es: return "Envío automático: cada \(interval)s"
        case .it: return "Invio automatico: ogni \(interval)s"
        case .fr: return "Envoi auto : toutes les \(interval)s"
        case .ko: return "자동 전송: \(interval)초 간격"
        case .zh: return "自动发送：每 \(interval) 秒"
        case .ja: return "自動送信: \(interval)秒間隔"
        }
    }

    static func manualSendLabel(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Manual send"
        case .de: return "Manuelles Senden"
        case .es: return "Envío manual"
        case .it: return "Invio manuale"
        case .fr: return "Envoi manuel"
        case .ko: return "수동 전송"
        case .zh: return "手动发送"
        case .ja: return "手動送信"
        }
    }

    static func lastSent(at: Date, locale: Locale = .current) -> String {
        let time = at.formatted(date: .omitted, time: .standard)
        switch language(for: locale) {
        case .en: return "Last sent: \(time)"
        case .de: return "Letzte Übertragung: \(time)"
        case .es: return "Último envío: \(time)"
        case .it: return "Ultimo invio: \(time)"
        case .fr: return "Dernier envoi : \(time)"
        case .ko: return "마지막 전송: \(time)"
        case .zh: return "最后发送：\(time)"
        case .ja: return "最終送信: \(time)"
        }
    }

    static func temperature(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Temp"
        case .de: return "Temperatur"
        case .es: return "Temperatura"
        case .it: return "Temperatura"
        case .fr: return "Température"
        case .ko: return "온도"
        case .zh: return "温度"
        case .ja: return "温度"
        }
    }

    static func humidity(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Humidity"
        case .de: return "Luftfeuchte"
        case .es: return "Humedad"
        case .it: return "Umidità"
        case .fr: return "Humidité"
        case .ko: return "습도"
        case .zh: return "湿度"
        case .ja: return "湿度"
        }
    }

    static func acceleration(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Acceleration"
        case .de: return "Beschleunigung"
        case .es: return "Aceleración"
        case .it: return "Accelerazione"
        case .fr: return "Accélération"
        case .ko: return "가속도"
        case .zh: return "加速度"
        case .ja: return "加速度"
        }
    }

    static func gps(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "GPS"
        case .de: return "GPS"
        case .es: return "GPS"
        case .it: return "GPS"
        case .fr: return "GPS"
        case .ko: return "GPS"
        case .zh: return "GPS"
        case .ja: return "GPS"
        }
    }

    static func invalid(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Invalid"
        case .de: return "Ungültig"
        case .es: return "No válido"
        case .it: return "Non valido"
        case .fr: return "Invalide"
        case .ko: return "무효"
        case .zh: return "无效"
        case .ja: return "無効"
        }
    }

    static func noSignal(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "No signal"
        case .de: return "Kein Signal"
        case .es: return "Sin señal"
        case .it: return "Nessun segnale"
        case .fr: return "Aucun signal"
        case .ko: return "신호 없음"
        case .zh: return "无信号"
        case .ja: return "信号なし"
        }
    }

    static func sendLogTitle(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Send Logs"
        case .de: return "Sendeprotokoll"
        case .es: return "Registros de envío"
        case .it: return "Log di invio"
        case .fr: return "Journaux d'envoi"
        case .ko: return "전송 로그"
        case .zh: return "发送日志"
        case .ja: return "送信ログ"
        }
    }

    static func clear(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Clear"
        case .de: return "Löschen"
        case .es: return "Borrar"
        case .it: return "Cancella"
        case .fr: return "Effacer"
        case .ko: return "삭제"
        case .zh: return "清除"
        case .ja: return "消去"
        }
    }

    static func noSendLogTitle(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "No send logs"
        case .de: return "Keine Sendeprotokolle"
        case .es: return "Sin registros de envío"
        case .it: return "Nessun log di invio"
        case .fr: return "Aucun journal d'envoi"
        case .ko: return "전송 로그 없음"
        case .zh: return "没有发送日志"
        case .ja: return "送信ログなし"
        }
    }

    static func noSendLogDescription(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Logs will appear here after sending data."
        case .de: return "Nach dem Senden von Daten werden hier Protokolle angezeigt."
        case .es: return "Los registros se mostrarán aquí después de enviar datos."
        case .it: return "I log verranno mostrati qui dopo l'invio dei dati."
        case .fr: return "Les journaux apparaîtront ici après l'envoi des données."
        case .ko: return "데이터를 전송하면 여기에 로그가 표시됩니다."
        case .zh: return "发送数据后，日志将显示在这里。"
        case .ja: return "データを送信するとここにログが表示されます。"
        }
    }

    static func sensorValuesToggle(expanded: Bool, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return expanded ? "Hide sensor values" : "Show sensor values"
        case .de: return expanded ? "Sensorwerte ausblenden" : "Sensorwerte anzeigen"
        case .es: return expanded ? "Ocultar valores del sensor" : "Mostrar valores del sensor"
        case .it: return expanded ? "Nascondi valori sensore" : "Mostra valori sensore"
        case .fr: return expanded ? "Masquer les valeurs du capteur" : "Afficher les valeurs du capteur"
        case .ko: return expanded ? "센서 값 닫기" : "센서 값 표시"
        case .zh: return expanded ? "隐藏传感器值" : "显示传感器值"
        case .ja: return expanded ? "センサー値を閉じる" : "センサー値を表示"
        }
    }

    static func latitude(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Latitude"
        case .de: return "Breitengrad"
        case .es: return "Latitud"
        case .it: return "Latitudine"
        case .fr: return "Latitude"
        case .ko: return "위도"
        case .zh: return "纬度"
        case .ja: return "緯度"
        }
    }

    static func longitude(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Longitude"
        case .de: return "Längengrad"
        case .es: return "Longitud"
        case .it: return "Longitudine"
        case .fr: return "Longitude"
        case .ko: return "경도"
        case .zh: return "经度"
        case .ja: return "経度"
        }
    }

    static func sendType(_ type: SendType, locale: Locale = .current) -> String {
        switch type {
        case .periodic:
            switch language(for: locale) {
            case .en: return "Auto"
            case .de: return "Automatisch"
            case .es: return "Automático"
            case .it: return "Automatico"
            case .fr: return "Auto"
            case .ko: return "자동"
            case .zh: return "自动"
            case .ja: return "自動"
            }
        case .manual:
            switch language(for: locale) {
            case .en: return "Manual"
            case .de: return "Manuell"
            case .es: return "Manual"
            case .it: return "Manuale"
            case .fr: return "Manuel"
            case .ko: return "수동"
            case .zh: return "手动"
            case .ja: return "手動"
            }
        case .accelerationAlert:
            switch language(for: locale) {
            case .en: return "Acceleration"
            case .de: return "Beschleunigung"
            case .es: return "Aceleración"
            case .it: return "Accelerazione"
            case .fr: return "Accélération"
            case .ko: return "가속도"
            case .zh: return "加速度"
            case .ja: return "加速度"
            }
        }
    }

    static func connectionDisconnected(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Disconnected"
        case .de: return "Getrennt"
        case .es: return "Desconectado"
        case .it: return "Disconnesso"
        case .fr: return "Déconnecté"
        case .ko: return "연결 안 됨"
        case .zh: return "未连接"
        case .ja: return "未接続"
        }
    }

    static func connectionConnecting(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Connecting..."
        case .de: return "Verbinden..."
        case .es: return "Conectando..."
        case .it: return "Connessione..."
        case .fr: return "Connexion..."
        case .ko: return "연결 중..."
        case .zh: return "连接中..."
        case .ja: return "接続中..."
        }
    }

    static func connectionConnected(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Connected"
        case .de: return "Verbunden"
        case .es: return "Conectado"
        case .it: return "Connesso"
        case .fr: return "Connecté"
        case .ko: return "연결됨"
        case .zh: return "已连接"
        case .ja: return "接続済み"
        }
    }

    static func connectionFailed(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Connection failed"
        case .de: return "Verbindung fehlgeschlagen"
        case .es: return "Conexión fallida"
        case .it: return "Connessione non riuscita"
        case .fr: return "Échec de la connexion"
        case .ko: return "연결 실패"
        case .zh: return "连接失败"
        case .ja: return "接続失敗"
        }
    }

    static func arcNotConfigured(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "SORACOM Arc is not configured. Enter WireGuard settings from Settings."
        case .de: return "SORACOM Arc ist nicht konfiguriert. Geben Sie die WireGuard-Einstellungen in den Einstellungen ein."
        case .es: return "SORACOM Arc no está configurado. Introduce la configuración de WireGuard desde Ajustes."
        case .it: return "SORACOM Arc non è configurato. Inserisci le impostazioni WireGuard da Impostazioni."
        case .fr: return "SORACOM Arc n'est pas configuré. Saisissez les paramètres WireGuard depuis Réglages."
        case .ko: return "SORACOM Arc가 설정되지 않았습니다. 설정 화면에서 WireGuard 정보를 입력하세요."
        case .zh: return "SORACOM Arc 尚未配置。请在设置中输入 WireGuard 配置。"
        case .ja: return "SORACOM Arc が設定されていません。設定画面から WireGuard 接続情報を入力してください。"
        }
    }

    static func invalidConfiguration(_ message: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Invalid configuration: \(message)"
        case .de: return "Ungültige Konfiguration: \(message)"
        case .es: return "Configuración no válida: \(message)"
        case .it: return "Configurazione non valida: \(message)"
        case .fr: return "Configuration invalide : \(message)"
        case .ko: return "설정이 유효하지 않습니다: \(message)"
        case .zh: return "配置无效：\(message)"
        case .ja: return "設定が無効です: \(message)"
        }
    }

    static func sendFailed(_ message: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Send failed: \(message)"
        case .de: return "Senden fehlgeschlagen: \(message)"
        case .es: return "Error al enviar: \(message)"
        case .it: return "Invio non riuscito: \(message)"
        case .fr: return "Échec de l'envoi : \(message)"
        case .ko: return "전송에 실패했습니다: \(message)"
        case .zh: return "发送失败：\(message)"
        case .ja: return "送信に失敗しました: \(message)"
        }
    }

    static func libraryUnavailable(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "libsoratun library is unavailable."
        case .de: return "Die libsoratun-Bibliothek ist nicht verfügbar."
        case .es: return "La biblioteca libsoratun no está disponible."
        case .it: return "La libreria libsoratun non è disponibile."
        case .fr: return "La bibliothèque libsoratun est indisponible."
        case .ko: return "libsoratun 라이브러리를 사용할 수 없습니다."
        case .zh: return "libsoratun 库不可用。"
        case .ja: return "libsoratun ライブラリが利用できません。"
        }
    }

    static func wireGuardParseFailed(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Could not parse WireGuard settings. PrivateKey, Address, PublicKey, AllowedIPs and Endpoint are required."
        case .de: return "WireGuard-Einstellungen konnten nicht analysiert werden. PrivateKey, Address, PublicKey, AllowedIPs und Endpoint sind erforderlich."
        case .es: return "No se pudo analizar la configuración de WireGuard. Se requieren PrivateKey, Address, PublicKey, AllowedIPs y Endpoint."
        case .it: return "Impossibile analizzare le impostazioni WireGuard. Sono richiesti PrivateKey, Address, PublicKey, AllowedIPs ed Endpoint."
        case .fr: return "Impossible d'analyser les paramètres WireGuard. PrivateKey, Address, PublicKey, AllowedIPs et Endpoint sont requis."
        case .ko: return "WireGuard 설정을 해석할 수 없습니다. PrivateKey, Address, PublicKey, AllowedIPs, Endpoint가 필요합니다."
        case .zh: return "无法解析 WireGuard 设置。需要 PrivateKey、Address、PublicKey、AllowedIPs、Endpoint。"
        case .ja: return "WireGuard 設定を解析できませんでした。PrivateKey・Address・PublicKey・AllowedIPs・Endpoint が必要です。"
        }
    }

    static func wireGuardOrJsonRequired(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Enter WireGuard settings or valid JSON."
        case .de: return "Geben Sie WireGuard-Einstellungen oder gültiges JSON ein."
        case .es: return "Introduce la configuración de WireGuard o JSON válido."
        case .it: return "Inserisci le impostazioni WireGuard o JSON valido."
        case .fr: return "Saisissez les paramètres WireGuard ou un JSON valide."
        case .ko: return "WireGuard 설정 또는 유효한 JSON을 입력하세요."
        case .zh: return "请输入 WireGuard 设置或有效的 JSON。"
        case .ja: return "WireGuard 設定または有効な JSON を入力してください。"
        }
    }

    static func soratunConversionFailed(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Could not convert soratun JSON format to libsoratun format."
        case .de: return "Das soratun-JSON-Format konnte nicht in das libsoratun-Format konvertiert werden."
        case .es: return "No se pudo convertir el formato JSON de soratun al formato libsoratun."
        case .it: return "Impossibile convertire il formato JSON soratun nel formato libsoratun."
        case .fr: return "Impossible de convertir le format JSON soratun au format libsoratun."
        case .ko: return "soratun 형식 JSON을 libsoratun 형식으로 변환하지 못했습니다."
        case .zh: return "无法将 soratun JSON 格式转换为 libsoratun 格式。"
        case .ja: return "soratun 形式の JSON を libsoratun 形式に変換できませんでした"
        }
    }

    static func missingArcSessionStatus(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "arcSessionStatus field is missing. Paste WireGuard settings or soratun arc.json."
        case .de: return "Das Feld arcSessionStatus fehlt. Fügen Sie WireGuard-Einstellungen oder soratun arc.json ein."
        case .es: return "Falta el campo arcSessionStatus. Pega la configuración de WireGuard o soratun arc.json."
        case .it: return "Manca il campo arcSessionStatus. Incolla impostazioni WireGuard o soratun arc.json."
        case .fr: return "Le champ arcSessionStatus est manquant. Collez les paramètres WireGuard ou soratun arc.json."
        case .ko: return "arcSessionStatus 필드가 없습니다. WireGuard 설정 또는 soratun arc.json을 붙여 넣으세요."
        case .zh: return "缺少 arcSessionStatus 字段。请粘贴 WireGuard 设置或 soratun arc.json。"
        case .ja: return "arcSessionStatus フィールドがありません。WireGuard 設定または soratun の arc.json を貼り付けてください。"
        }
    }

    static func responseWasNull(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Response was null."
        case .de: return "Antwort war null."
        case .es: return "La respuesta fue null."
        case .it: return "La risposta era null."
        case .fr: return "La réponse était null."
        case .ko: return "응답이 null이었습니다."
        case .zh: return "响应为 null。"
        case .ja: return "レスポンスが null でした"
        }
    }

    static func emptyResponse(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Response was empty."
        case .de: return "Antwort war leer."
        case .es: return "La respuesta estaba vacía."
        case .it: return "La risposta era vuota."
        case .fr: return "La réponse était vide."
        case .ko: return "응답이 비어 있었습니다."
        case .zh: return "响应为空。"
        case .ja: return "レスポンスが空でした"
        }
    }

    static func utf8DecodeFailed(_ hex: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Could not decode as UTF-8: \(hex)"
        case .de: return "Konnte nicht als UTF-8 dekodiert werden: \(hex)"
        case .es: return "No se pudo decodificar como UTF-8: \(hex)"
        case .it: return "Impossibile decodificare come UTF-8: \(hex)"
        case .fr: return "Impossible de décoder en UTF-8 : \(hex)"
        case .ko: return "UTF-8로 해석할 수 없습니다: \(hex)"
        case .zh: return "无法按 UTF-8 解析：\(hex)"
        case .ja: return "UTF-8 として解釈できません: \(hex)"
        }
    }

    static func invalidResponse(_ response: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Invalid response: \(response)"
        case .de: return "Ungültige Antwort: \(response)"
        case .es: return "Respuesta no válida: \(response)"
        case .it: return "Risposta non valida: \(response)"
        case .fr: return "Réponse invalide : \(response)"
        case .ko: return "유효하지 않은 응답: \(response)"
        case .zh: return "响应无效：\(response)"
        case .ja: return "不正なレスポンス: \(response)"
        }
    }

    static func udpMessageTooLarge(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP message is too large"
        case .de: return "UDP-Nachricht ist zu groß"
        case .es: return "El mensaje UDP es demasiado grande"
        case .it: return "Il messaggio UDP è troppo grande"
        case .fr: return "Le message UDP est trop volumineux"
        case .ko: return "UDP 메시지가 너무 큽니다"
        case .zh: return "UDP 消息过大"
        case .ja: return "UDP メッセージが大きすぎます"
        }
    }

    static func udpResponseWasNull(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP response was null."
        case .de: return "UDP-Antwort war null."
        case .es: return "La respuesta UDP fue null."
        case .it: return "La risposta UDP era null."
        case .fr: return "La réponse UDP était null."
        case .ko: return "UDP 응답이 null이었습니다."
        case .zh: return "UDP 响应为 null。"
        case .ja: return "UDP レスポンスが null でした"
        }
    }

    static func udpResponseInvalid(_ response: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP response is invalid: \(response)"
        case .de: return "UDP-Antwort ist ungültig: \(response)"
        case .es: return "La respuesta UDP no es válida: \(response)"
        case .it: return "La risposta UDP non è valida: \(response)"
        case .fr: return "La réponse UDP est invalide : \(response)"
        case .ko: return "UDP 응답이 올바르지 않습니다: \(response)"
        case .zh: return "UDP 响应无效：\(response)"
        case .ja: return "UDP レスポンスが不正です: \(response)"
        }
    }

    static func mockError(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Mock error"
        case .de: return "Mock-Fehler"
        case .es: return "Error simulado"
        case .it: return "Errore mock"
        case .fr: return "Erreur simulée"
        case .ko: return "모의 오류"
        case .zh: return "模拟错误"
        case .ja: return "モックエラー"
        }
    }

    static func metadataInvalidResponse(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Received an invalid response from metadata service."
        case .de: return "Ungültige Antwort vom Metadatendienst empfangen."
        case .es: return "Se recibió una respuesta no válida del servicio de metadatos."
        case .it: return "Ricevuta una risposta non valida dal servizio metadati."
        case .fr: return "Réponse invalide reçue du service de métadonnées."
        case .ko: return "메타데이터 서비스에서 잘못된 응답을 받았습니다."
        case .zh: return "从元数据服务收到无效响应。"
        case .ja: return "メタデータサービスから無効なレスポンスを受信しました。"
        }
    }

    static func metadataDecodingFailed(_ detail: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Failed to parse metadata: \(detail)"
        case .de: return "Metadaten konnten nicht analysiert werden: \(detail)"
        case .es: return "Error al analizar metadatos: \(detail)"
        case .it: return "Analisi metadati non riuscita: \(detail)"
        case .fr: return "Échec de l'analyse des métadonnées : \(detail)"
        case .ko: return "메타데이터 분석에 실패했습니다: \(detail)"
        case .zh: return "元数据解析失败：\(detail)"
        case .ja: return "メタデータの解析に失敗しました: \(detail)"
        }
    }

    static func dataEncodingFailed(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Failed to encode sensor data to JSON."
        case .de: return "Sensor-Daten konnten nicht in JSON codiert werden."
        case .es: return "No se pudieron convertir los datos del sensor a JSON."
        case .it: return "Impossibile codificare i dati del sensore in JSON."
        case .fr: return "Échec de l'encodage des données du capteur en JSON."
        case .ko: return "센서 데이터를 JSON으로 변환하지 못했습니다."
        case .zh: return "将传感器数据转换为 JSON 失败。"
        case .ja: return "センサーデータの JSON 変換に失敗しました。"
        }
    }

    static func arcFallbackDisabled(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Send failed because SORACOM Arc is unavailable and UDP fallback over the internet is disabled."
        case .de: return "Senden fehlgeschlagen, da SORACOM Arc nicht verfügbar ist und der UDP-Fallback über das Internet deaktiviert ist."
        case .es: return "Error al enviar: SORACOM Arc no está disponible y el respaldo UDP por Internet está deshabilitado."
        case .it: return "Invio non riuscito perché SORACOM Arc non è disponibile e il fallback UDP via Internet è disabilitato."
        case .fr: return "Échec de l'envoi, car SORACOM Arc est indisponible et le secours UDP via Internet est désactivé."
        case .ko: return "SORACOM Arc를 사용할 수 없고 인터넷 경유 UDP 폴백이 비활성화되어 전송에 실패했습니다."
        case .zh: return "发送失败：SORACOM Arc 不可用，且互联网 UDP 回退已禁用。"
        case .ja: return "SORACOM Arc を利用できず、インターネット経由 UDP のフォールバックが無効なため送信に失敗しました。"
        }
    }

    static func dataSendFailed(_ detail: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "Data send failed: \(detail)"
        case .de: return "Datenversand fehlgeschlagen: \(detail)"
        case .es: return "Error al enviar datos: \(detail)"
        case .it: return "Invio dati non riuscito: \(detail)"
        case .fr: return "Échec de l'envoi des données : \(detail)"
        case .ko: return "데이터 전송에 실패했습니다: \(detail)"
        case .zh: return "数据发送失败：\(detail)"
        case .ja: return "データ送信に失敗しました: \(detail)"
        }
    }

    static func udpConnectionFailed(_ detail: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP connection failed: \(detail)"
        case .de: return "UDP-Verbindung fehlgeschlagen: \(detail)"
        case .es: return "Conexión UDP fallida: \(detail)"
        case .it: return "Connessione UDP non riuscita: \(detail)"
        case .fr: return "Échec de la connexion UDP : \(detail)"
        case .ko: return "UDP 연결에 실패했습니다: \(detail)"
        case .zh: return "UDP 连接失败：\(detail)"
        case .ja: return "UDP 接続に失敗しました: \(detail)"
        }
    }

    static func udpSendFailed(_ detail: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP send failed: \(detail)"
        case .de: return "UDP-Senden fehlgeschlagen: \(detail)"
        case .es: return "Error al enviar UDP: \(detail)"
        case .it: return "Invio UDP non riuscito: \(detail)"
        case .fr: return "Échec de l'envoi UDP : \(detail)"
        case .ko: return "UDP 전송에 실패했습니다: \(detail)"
        case .zh: return "UDP 发送失败：\(detail)"
        case .ja: return "UDP 送信に失敗しました: \(detail)"
        }
    }

    static func udpReceiveFailed(_ detail: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP response receive failed: \(detail)"
        case .de: return "Empfang der UDP-Antwort fehlgeschlagen: \(detail)"
        case .es: return "Error al recibir respuesta UDP: \(detail)"
        case .it: return "Ricezione risposta UDP non riuscita: \(detail)"
        case .fr: return "Échec de la réception de la réponse UDP : \(detail)"
        case .ko: return "UDP 응답 수신에 실패했습니다: \(detail)"
        case .zh: return "UDP 响应接收失败：\(detail)"
        case .ja: return "UDP レスポンス受信に失敗しました: \(detail)"
        }
    }

    static func udpInvalidResponse(_ detail: String, locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP response is invalid: \(detail)"
        case .de: return "UDP-Antwort ist ungültig: \(detail)"
        case .es: return "La respuesta UDP no es válida: \(detail)"
        case .it: return "La risposta UDP non è valida: \(detail)"
        case .fr: return "La réponse UDP est invalide : \(detail)"
        case .ko: return "UDP 응답이 올바르지 않습니다: \(detail)"
        case .zh: return "UDP 响应无效：\(detail)"
        case .ja: return "UDP レスポンスが不正です: \(detail)"
        }
    }

    static func udpTimeout(locale: Locale = .current) -> String {
        switch language(for: locale) {
        case .en: return "UDP communication timed out"
        case .de: return "UDP-Kommunikation hat Zeitüberschreitung"
        case .es: return "Se agotó el tiempo de espera de la comunicación UDP"
        case .it: return "Timeout della comunicazione UDP"
        case .fr: return "Délai d'attente de la communication UDP dépassé"
        case .ko: return "UDP 통신이 시간 초과되었습니다"
        case .zh: return "UDP 通信超时"
        case .ja: return "UDP 通信がタイムアウトしました"
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
