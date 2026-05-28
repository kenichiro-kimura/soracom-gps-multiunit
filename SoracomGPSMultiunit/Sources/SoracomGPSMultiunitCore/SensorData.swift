import Foundation

/// GPS マルチユニット SORACOM Edition と同形式のセンサーデータ
public struct SensorData: Codable, Equatable, Sendable {
    /// 緯度 (度)。-90 〜 90、null: 測位失敗
    public let lat: Double?
    /// 経度 (度)。-180 〜 180、null: 測位失敗
    public let lon: Double?
    /// 温度 (°C)。-20 〜 60。センサー無効時は nil
    public let temp: Double?
    /// 湿度 (%)。0 〜 100。センサー無効時は nil
    public let humi: Double?
    /// 加速度 X軸 (mG)。-8128 〜 8128。センサー無効時は nil
    public let x: Double?
    /// 加速度 Y軸 (mG)。-8128 〜 8128。センサー無効時は nil
    public let y: Double?
    /// 加速度 Z軸 (mG)。-8128 〜 8128。センサー無効時は nil
    public let z: Double?
    /// 電池残量。-1: 充電中、1 〜 3: 電池残量
    public let bat: Int?
    /// 電波強度。-1: 圏外、0 〜 4: 電波強度
    public let rs: Int?
    /// 送信種別。0: 定期送信、1: 手動送信
    public let type: SendType

    public enum CodingKeys: String, CodingKey {
        case lat, lon, temp, humi, x, y, z, bat, rs, type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lon, forKey: .lon)
        try container.encodeIfPresent(bat, forKey: .bat)
        try container.encodeIfPresent(rs, forKey: .rs)
        try container.encodeIfPresent(temp, forKey: .temp)
        try container.encodeIfPresent(humi, forKey: .humi)
        try container.encodeIfPresent(x, forKey: .x)
        try container.encodeIfPresent(y, forKey: .y)
        try container.encodeIfPresent(z, forKey: .z)
        try container.encode(type, forKey: .type)
    }

    public init(
        lat: Double? = nil,
        lon: Double? = nil,
        temp: Double? = nil,
        humi: Double? = nil,
        x: Double? = nil,
        y: Double? = nil,
        z: Double? = nil,
        bat: Int? = nil,
        rs: Int? = nil,
        type: SendType
    ) {
        self.lat = lat
        self.lon = lon
        self.temp = temp
        self.humi = humi
        self.x = x
        self.y = y
        self.z = z
        self.bat = bat
        self.rs = rs
        self.type = type
    }
}

/// 送信種別
public enum SendType: Int, Codable, Sendable {
    /// タイマー自動送信
    case periodic = 0
    /// スイッチ押下による手動送信
    case manual = 1
    /// 加速度アラート
    case accelerationAlert = 2
}
