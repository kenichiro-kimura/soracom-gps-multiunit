import Foundation

/// GPS Multiunit SORACOM Edition と同形式のセンサーデータ
struct SensorData: Codable, Equatable {
    /// 緯度 (degrees)
    let lat: Double?
    /// 経度 (degrees)
    let lon: Double?
    /// 高度 (meters)
    let alt: Double?
    /// 速度 (km/h)
    let speed: Double?
    /// 温度 (°C)
    let temp: Double
    /// 湿度 (%)
    let humi: Double
    /// 加速度 X軸 (G)
    let x: Double
    /// 加速度 Y軸 (G)
    let y: Double
    /// 加速度 Z軸 (G)
    let z: Double
    /// バッテリーレベル (0-5)
    let bat: Int?
    /// 電波強度 (dBm)
    let rs: Int?
    /// 送信種別
    let type: SendType

    enum CodingKeys: String, CodingKey {
        case lat, lon, alt, speed, temp, humi, x, y, z, bat, rs, type
    }
}

/// 送信種別
enum SendType: Int, Codable {
    /// タイマー自動送信
    case periodic = 0
    /// スイッチ押下による手動送信
    case manual = 1
    /// 加速度アラート
    case accelerationAlert = 2
}
