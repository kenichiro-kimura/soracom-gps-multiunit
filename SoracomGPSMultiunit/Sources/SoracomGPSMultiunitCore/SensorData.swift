import Foundation

/// GPS マルチユニット SORACOM Edition と同形式のセンサーデータ
public struct SensorData: Codable, Equatable, Sendable {
    /// 緯度 (degrees)
    public let lat: Double?
    /// 経度 (degrees)
    public let lon: Double?
    /// 高度 (meters)
    public let alt: Double?
    /// 速度 (km/h)
    public let speed: Double?
    /// 温度 (°C)
    public let temp: Double
    /// 湿度 (%)
    public let humi: Double
    /// 加速度 X軸 (G)
    public let x: Double
    /// 加速度 Y軸 (G)
    public let y: Double
    /// 加速度 Z軸 (G)
    public let z: Double
    /// バッテリーレベル (0-5)
    public let bat: Int?
    /// 電波強度 (dBm)
    public let rs: Int?
    /// 送信種別
    public let type: SendType

    public enum CodingKeys: String, CodingKey {
        case lat, lon, alt, speed, temp, humi, x, y, z, bat, rs, type
    }

    public init(
        lat: Double? = nil,
        lon: Double? = nil,
        alt: Double? = nil,
        speed: Double? = nil,
        temp: Double,
        humi: Double,
        x: Double,
        y: Double,
        z: Double,
        bat: Int? = nil,
        rs: Int? = nil,
        type: SendType
    ) {
        self.lat = lat
        self.lon = lon
        self.alt = alt
        self.speed = speed
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
