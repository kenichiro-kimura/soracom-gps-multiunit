import Foundation

/// 接続ステータス
public enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    public var displayText: String {
        switch self {
        case .disconnected: return "未接続"
        case .connecting: return "接続中..."
        case .connected: return "接続済み"
        case .failed: return "接続失敗"
        }
    }
}

/// 温度・湿度のランダム値生成ユーティリティ
public struct SensorValueGenerator: Sendable {
    public let temperatureBase: Double
    public let temperatureVariation: Double
    public let humidityBase: Double
    public let humidityVariation: Double

    public init(
        temperatureBase: Double = 25.0,
        temperatureVariation: Double = 2.0,
        humidityBase: Double = 60.0,
        humidityVariation: Double = 5.0
    ) {
        self.temperatureBase = temperatureBase
        self.temperatureVariation = temperatureVariation
        self.humidityBase = humidityBase
        self.humidityVariation = humidityVariation
    }

    /// 温度値を生成する (ベース値 ± 変動幅)
    public func generateTemperature() -> Double {
        let variation = Double.random(in: -temperatureVariation...temperatureVariation)
        let value = temperatureBase + variation
        return (value * 10).rounded() / 10
    }

    /// 湿度値を生成する (ベース値 ± 変動幅、0〜100 にクランプ)
    public func generateHumidity() -> Double {
        let variation = Double.random(in: -humidityVariation...humidityVariation)
        let value = (humidityBase + variation).clamped(to: 0...100)
        return (value * 10).rounded() / 10
    }
}

// MARK: - Comparable Extension

public extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
