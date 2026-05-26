import Foundation
import Combine

/// アプリ設定
class AppSettings: ObservableObject {
    // MARK: - 温度/湿度設定

    /// 温度ベース値 (°C)
    @Published var temperatureBase: Double {
        didSet { UserDefaults.standard.set(temperatureBase, forKey: Keys.temperatureBase) }
    }

    /// 温度ランダム変動範囲 (±°C)
    @Published var temperatureVariation: Double {
        didSet { UserDefaults.standard.set(temperatureVariation, forKey: Keys.temperatureVariation) }
    }

    /// 湿度ベース値 (%)
    @Published var humidityBase: Double {
        didSet { UserDefaults.standard.set(humidityBase, forKey: Keys.humidityBase) }
    }

    /// 湿度ランダム変動範囲 (±%)
    @Published var humidityVariation: Double {
        didSet { UserDefaults.standard.set(humidityVariation, forKey: Keys.humidityVariation) }
    }

    // MARK: - SORACOM Arc 設定

    /// SORACOM Arc 設定 JSON (arc.json の内容)
    @Published var arcConfigJSON: String {
        didSet { UserDefaults.standard.set(arcConfigJSON, forKey: Keys.arcConfigJSON) }
    }

    // MARK: - 電波強度・バッテリー設定

    /// 電波強度 (0-5)
    @Published var rsValue: Int {
        didSet { UserDefaults.standard.set(rsValue, forKey: Keys.rsValue) }
    }

    /// バッテリーレベル (0-5)
    @Published var batValue: Int {
        didSet { UserDefaults.standard.set(batValue, forKey: Keys.batValue) }
    }

    // MARK: - フォールバック設定

    /// メタデータサービスが利用できない場合の自動送信間隔 (秒)
    @Published var defaultSendingInterval: Int {
        didSet { UserDefaults.standard.set(defaultSendingInterval, forKey: Keys.defaultSendingInterval) }
    }

    /// メタデータサービスが利用できない場合の自動送信有効/無効
    @Published var defaultAutoSend: Bool {
        didSet { UserDefaults.standard.set(defaultAutoSend, forKey: Keys.defaultAutoSend) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        temperatureBase = defaults.object(forKey: Keys.temperatureBase) as? Double ?? 25.0
        temperatureVariation = defaults.object(forKey: Keys.temperatureVariation) as? Double ?? 2.0
        humidityBase = defaults.object(forKey: Keys.humidityBase) as? Double ?? 60.0
        humidityVariation = defaults.object(forKey: Keys.humidityVariation) as? Double ?? 5.0
        arcConfigJSON = defaults.string(forKey: Keys.arcConfigJSON) ?? ""
        rsValue = defaults.object(forKey: Keys.rsValue) as? Int ?? 3
        batValue = defaults.object(forKey: Keys.batValue) as? Int ?? 3
        defaultSendingInterval = defaults.object(forKey: Keys.defaultSendingInterval) as? Int ?? 60
        defaultAutoSend = defaults.object(forKey: Keys.defaultAutoSend) as? Bool ?? false
    }

    // MARK: - Keys

    private enum Keys {
        static let temperatureBase = "temperatureBase"
        static let temperatureVariation = "temperatureVariation"
        static let humidityBase = "humidityBase"
        static let humidityVariation = "humidityVariation"
        static let arcConfigJSON = "arcConfigJSON"
        static let rsValue = "rsValue"
        static let batValue = "batValue"
        static let defaultSendingInterval = "defaultSendingInterval"
        static let defaultAutoSend = "defaultAutoSend"
    }
}
