import Foundation

// MARK: - センサー設定

/// センサーのオン/オフ設定
struct SensorSwitch: Codable, Equatable {
    let i1: String
    var isEnabled: Bool { i1 == "ON" }
}

/// SensorData セクション — 計測・送信するセンサーの設定
struct SensorDataConfig: Codable, Equatable {
    let acc: SensorSwitch?  // 加速度
    let loc: SensorSwitch?  // GPS 位置情報
    let tem: SensorSwitch?  // 温度
    let hum: SensorSwitch?  // 湿度
    let bat: SensorSwitch?  // バッテリー
}

// MARK: - Common スケジュール設定

/// C6 の要素 — "null" (無効) または曜日の配列
enum DaySchedule: Codable, Equatable {
    case disabled
    case days([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if (try? container.decode(String.self)) != nil {
            self = .disabled
        } else {
            self = .days(try container.decode([String].self))
        }
    }

    func encode(to encoder: Encoder) throws {
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
struct CommonConfig: Codable, Equatable {
    /// 期間開始日 ("null" or "YYYY/MM/DD")
    let c1: [String]
    /// 期間終了日 ("null" or "YYYY/MM/DD")
    let c2: [String]
    /// 時刻開始 ("null" or "HH:mm")
    let c3: [String]
    /// 時刻終了 ("null" or "HH:mm")
    let c4: [String]
    /// 送信/取得間隔 (分, -20000 = 無効)
    let c5: [Int]
    /// 曜日設定
    let c6: [DaySchedule]
    /// 有効スロット番号 (カンマ区切り文字列, 例: "5,6,7")
    let c7: String

    enum CodingKeys: String, CodingKey {
        case c1 = "C1", c2 = "C2", c3 = "C3", c4 = "C4"
        case c5 = "C5", c6 = "C6", c7 = "C7"
    }

    /// 有効スロットのインデックス一覧
    var activeIndices: [Int] {
        c7.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
}

// MARK: - Setting セクション

/// 加速度割り込み設定
struct InterruptConfig: Codable, Equatable {
    /// 加速度割り込みしきい値 (mG)
    let i2: Int
}

/// Setting セクション
struct SettingConfig: Codable, Equatable {
    let itr: InterruptConfig
}

// MARK: - MetadataConfig

/// メタデータサービスから取得したデバイス設定
struct MetadataConfig: Codable, Equatable {
    let sensorData: SensorDataConfig
    let common: CommonConfig
    let setting: SettingConfig

    enum CodingKeys: String, CodingKey {
        case sensorData = "SensorData"
        case common = "Common"
        case setting = "Setting"
    }

    // MARK: - Computed properties

    /// 加速度センサーを送信するか
    var sendAcceleration: Bool { sensorData.acc?.isEnabled ?? false }
    /// GPS 位置情報を送信するか
    var sendLocation: Bool { sensorData.loc?.isEnabled ?? false }
    /// 温度を送信するか
    var sendTemperature: Bool { sensorData.tem?.isEnabled ?? false }
    /// 湿度を送信するか
    var sendHumidity: Bool { sensorData.hum?.isEnabled ?? false }

    /// 定期送信間隔 (秒)。有効スロット中の最初のものを使用。nil = 自動送信なし
    var sendingIntervalSeconds: Int? {
        guard let idx = common.activeIndices.first,
              idx < common.c5.count else { return nil }
        let minutes = common.c5[idx]
        guard minutes > 0 else { return nil }
        return minutes * 60
    }

    /// 自動送信が有効か
    var autoSend: Bool { (sendingIntervalSeconds ?? 0) > 0 }

    /// 加速度割り込みしきい値 (mG)
    var accelerometerThreshold: Int { setting.itr.i2 }
}

/// メタデータサービスのsubscriber情報
struct SubscriberMetadata: Codable {
    let imsi: String?
    let msisdn: String?
    let operatorId: String?
    let groupId: String?
}
