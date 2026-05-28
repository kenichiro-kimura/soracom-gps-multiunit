import Foundation

// MARK: - センサー設定

/// センサーのオン/オフ設定
public struct SensorSwitch: Codable, Equatable, Sendable {
    public let i1: String
    public var isEnabled: Bool { i1 == "ON" }
}

/// SensorData セクション — 計測・送信するセンサーの設定
public struct SensorDataConfig: Codable, Equatable, Sendable {
    public let acc: SensorSwitch?  // 加速度
    public let loc: SensorSwitch?  // GPS 位置情報
    public let tem: SensorSwitch?  // 温度
    public let hum: SensorSwitch?  // 湿度
    public let bat: SensorSwitch?  // バッテリー
}

// MARK: - Common スケジュール設定

/// C6 の要素 — "null" (無効) または曜日の配列
public enum DaySchedule: Codable, Equatable, Sendable {
    case disabled
    case days([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if (try? container.decode(String.self)) != nil {
            self = .disabled
        } else {
            self = .days(try container.decode([String].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .disabled:
            try container.encode("null")
        case .days(let d):
            try container.encode(d)
        }
    }
}

/// Common セクション — スケジュール設定 (10 スロット)
public struct CommonConfig: Codable, Equatable, Sendable {
    /// 期間開始日 ("null" or "YYYY/MM/DD")
    public let c1: [String]
    /// 期間終了日 ("null" or "YYYY/MM/DD")
    public let c2: [String]
    /// 時刻開始 ("null" or "HH:mm")
    public let c3: [String]
    /// 時刻終了 ("null" or "HH:mm")
    public let c4: [String]
    /// 送信/取得間隔 (分, -20000 = 無効)
    public let c5: [Int]
    /// 曜日設定
    public let c6: [DaySchedule]
    /// 有効スロット番号 (カンマ区切り文字列, 例: "5,6,7")
    public let c7: String

    enum CodingKeys: String, CodingKey {
        case c1 = "C1", c2 = "C2", c3 = "C3", c4 = "C4"
        case c5 = "C5", c6 = "C6", c7 = "C7"
    }

    /// 有効スロットのインデックス一覧
    public var activeIndices: [Int] {
        c7.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}

// MARK: - Setting セクション

/// 加速度割り込み設定
public struct InterruptConfig: Codable, Equatable, Sendable {
    /// 加速度割り込みしきい値 (mG)
    public let i2: Int
}

/// Setting セクション
public struct SettingConfig: Codable, Equatable, Sendable {
    public let itr: InterruptConfig
}

// MARK: - MetadataConfig

/// メタデータサービスから取得したデバイス設定
public struct MetadataConfig: Codable, Equatable, Sendable {
    public let sensorData: SensorDataConfig
    public let common: CommonConfig
    public let setting: SettingConfig

    enum CodingKeys: String, CodingKey {
        case sensorData = "SensorData"
        case common = "Common"
        case setting = "Setting"
    }

    // MARK: - Computed properties

    /// 加速度センサーを送信するか
    public var sendAcceleration: Bool { sensorData.acc?.isEnabled ?? false }
    /// GPS 位置情報を送信するか
    public var sendLocation: Bool { sensorData.loc?.isEnabled ?? false }
    /// 温度を送信するか
    public var sendTemperature: Bool { sensorData.tem?.isEnabled ?? false }
    /// 湿度を送信するか
    public var sendHumidity: Bool { sensorData.hum?.isEnabled ?? false }

    /// 定期送信間隔 (秒)。有効スロット中の最初のものを使用。nil = 自動送信なし
    public var sendingIntervalSeconds: Int? {
        guard let idx = common.activeIndices.first,
              idx < common.c5.count else { return nil }
        let minutes = common.c5[idx]
        guard minutes > 0 else { return nil }
        return minutes * 60
    }

    /// 自動送信が有効か
    public var autoSend: Bool { (sendingIntervalSeconds ?? 0) > 0 }

    /// 加速度割り込みしきい値 (mG)
    public var accelerometerThreshold: Int { setting.itr.i2 }
}

/// メタデータサービスのsubscriber情報
public struct SubscriberMetadata: Codable, Sendable {
    public let imsi: String?
    public let msisdn: String?
    public let operatorId: String?
    public let groupId: String?

    public init(imsi: String? = nil, msisdn: String? = nil,
                operatorId: String? = nil, groupId: String? = nil) {
        self.imsi = imsi
        self.msisdn = msisdn
        self.operatorId = operatorId
        self.groupId = groupId
    }
}
