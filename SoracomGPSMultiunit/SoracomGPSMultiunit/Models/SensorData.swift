import Foundation

/// GPS Multiunit SORACOM Edition と同形式のセンサーデータ
struct SensorData: Codable, Equatable {
    /// 緯度 (度)。-90 〜 90、null: 測位失敗
    let lat: Double?
    /// 経度 (度)。-180 〜 180、null: 測位失敗
    let lon: Double?
    /// 温度 (°C)。-20 〜 60。センサー無効時は nil
    let temp: Double?
    /// 湿度 (%)。0 〜 100。センサー無効時は nil
    let humi: Double?
    /// 加速度 X軸 (mG)。-8128 〜 8128。センサー無効時は nil
    let x: Double?
    /// 加速度 Y軸 (mG)。-8128 〜 8128。センサー無効時は nil
    let y: Double?
    /// 加速度 Z軸 (mG)。-8128 〜 8128。センサー無効時は nil
    let z: Double?
    /// 電池残量。-1: 充電中、1 〜 3: 電池残量
    let bat: Int?
    /// 電波強度。-1: 圏外、0 〜 4: 電波強度
    let rs: Int?
    /// 送信種別。0: 定期送信、1: 手動送信
    let type: SendType

    enum CodingKeys: String, CodingKey {
        case lat, lon, temp, humi, x, y, z, bat, rs, type
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // GPS未取得時もキーを送信し、値はJSONのnullにする。
        try container.encode(lat, forKey: .lat)
        try container.encode(lon, forKey: .lon)
        try container.encodeIfPresent(bat, forKey: .bat)
        try container.encodeIfPresent(rs, forKey: .rs)
        try container.encodeIfPresent(temp, forKey: .temp)
        try container.encodeIfPresent(humi, forKey: .humi)
        try container.encodeIfPresent(x, forKey: .x)
        try container.encodeIfPresent(y, forKey: .y)
        try container.encodeIfPresent(z, forKey: .z)
        try container.encode(type, forKey: .type)
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
