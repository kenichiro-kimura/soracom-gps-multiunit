import Foundation

/// SORACOM Unified Endpoint にセンサーデータを送信するサービス
///
/// まず SORACOM Arc VPN 経由での送信を試みます。
/// Arc が未設定・ライブラリ不可・設定不備の場合は通常のインターネット経由 UDP にフォールバックします。
class DataSendingService {
    private let arcService: SoracomArcServiceProtocol
    private let udpSendingService: UDPSendingService

    init(arcService: SoracomArcServiceProtocol) {
        self.arcService = arcService
        self.udpSendingService = UDPSendingService()
    }

    /// センサーデータを Unified Endpoint に送信する
    /// - Parameter sensorData: 送信するセンサーデータ
    /// - Returns: Arc またはインターネット経由 UDP の Unified Endpoint レスポンス
    @discardableResult
    func send(_ sensorData: SensorData, allowUdpFallback: Bool = true) async throws -> String {
        let jsonString = try sensorData.jsonString()

        // Arc 経由で Unified Endpoint の UDP ポートへ送信を試みる
        do {
            return try await arcService.sendUDP(body: jsonString)
        } catch let arcError as SoracomArcError {
            switch arcError {
            case .notConfigured, .libraryUnavailable, .invalidConfiguration:
                // Arc が使えない設定上の問題 → UDP フォールバック
                break
            case .sendFailed:
                // Arc は設定済みだが送信失敗 → そのまま throw
                throw arcError
            }
        }

        guard allowUdpFallback else {
            throw DataSendingError.arcFallbackDisabled
        }

        // UDP フォールバック: 通常インターネット経由で uni.soracom.io:23080 に送信
        return try await udpSendingService.send(Data(jsonString.utf8))
    }
}

// MARK: - Errors

enum DataSendingError: LocalizedError {
    case encodingFailed
    case arcFallbackDisabled
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "センサーデータの JSON 変換に失敗しました。"
        case .arcFallbackDisabled:
            return "SORACOM Arc を利用できず、インターネット経由 UDP のフォールバックが無効なため送信に失敗しました。"
        case .sendFailed(let detail):
            return "データ送信に失敗しました: \(detail)"
        }
    }
}
