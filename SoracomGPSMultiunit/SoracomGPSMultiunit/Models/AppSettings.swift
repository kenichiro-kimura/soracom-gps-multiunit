import Foundation
import Combine
import Security

// MARK: - Keychain Helper

private enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain access failed with status \(status)."
        }
    }
}

private enum KeychainHelper {
    private static let service = Bundle.main.bundleIdentifier ?? "com.gmail.kenichirokimura.gpsmultiunit"
    private static let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    static func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessibility

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility
            ]
            let updateStatus = SecItemUpdate(baseQuery(forKey: key) as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    static func load(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query.merge([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

/// アプリ設定
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    // MARK: - 温度/湿度設定

    /// 温度ベース値 (°C)
    @Published var temperatureBase: Double {
        didSet { defaults.set(temperatureBase, forKey: Keys.temperatureBase) }
    }

    /// 温度ランダム変動範囲 (±°C)
    @Published var temperatureVariation: Double {
        didSet { defaults.set(temperatureVariation, forKey: Keys.temperatureVariation) }
    }

    /// 湿度ベース値 (%)
    @Published var humidityBase: Double {
        didSet { defaults.set(humidityBase, forKey: Keys.humidityBase) }
    }

    /// 湿度ランダム変動範囲 (±%)
    @Published var humidityVariation: Double {
        didSet { defaults.set(humidityVariation, forKey: Keys.humidityVariation) }
    }

    // MARK: - SORACOM Arc 設定

    /// SORACOM Arc 設定 (WireGuard 形式) — Keychain に保存
    @Published var arcConfigJSON: String

    // MARK: - 電波強度・バッテリー設定

    /// 電波強度 (-1 - 4)
    @Published var rsValue: Int {
        didSet { defaults.set(rsValue, forKey: Keys.rsValue) }
    }

    /// バッテリーレベル (-1 - 3)
    @Published var batValue: Int {
        didSet { defaults.set(batValue, forKey: Keys.batValue) }
    }

    // MARK: - フォールバック設定

    /// メタデータサービスが利用できない場合の自動送信間隔 (秒)
    @Published var defaultSendingInterval: Int {
        didSet { defaults.set(defaultSendingInterval, forKey: Keys.defaultSendingInterval) }
    }

    /// メタデータサービスが利用できない場合の自動送信有効/無効
    @Published var defaultAutoSend: Bool {
        didSet { defaults.set(defaultAutoSend, forKey: Keys.defaultAutoSend) }
    }

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults

        temperatureBase = userDefaults.object(forKey: Keys.temperatureBase) as? Double ?? 25.0
        temperatureVariation = userDefaults.object(forKey: Keys.temperatureVariation) as? Double ?? 2.0
        humidityBase = userDefaults.object(forKey: Keys.humidityBase) as? Double ?? 60.0
        humidityVariation = userDefaults.object(forKey: Keys.humidityVariation) as? Double ?? 5.0
        arcConfigJSON = KeychainHelper.load(forKey: Keys.arcConfigJSON) ?? ""
        rsValue = userDefaults.object(forKey: Keys.rsValue) as? Int ?? 3
        batValue = userDefaults.object(forKey: Keys.batValue) as? Int ?? 3
        defaultSendingInterval = userDefaults.object(forKey: Keys.defaultSendingInterval) as? Int ?? 60
        defaultAutoSend = userDefaults.object(forKey: Keys.defaultAutoSend) as? Bool ?? false
    }

    func saveArcConfigJSON(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            try KeychainHelper.delete(forKey: Keys.arcConfigJSON)
            arcConfigJSON = ""
        } else {
            try KeychainHelper.save(trimmed, forKey: Keys.arcConfigJSON)
            arcConfigJSON = trimmed
        }
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
