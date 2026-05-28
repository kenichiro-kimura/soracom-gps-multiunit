import Foundation

/// SORACOM Unified Endpoint にセンサーデータを送信するサービス
///
/// まず SORACOM Arc VPN 経由での送信を試みます。
/// Arc が未設定・ライブラリ不可・設定不備の場合は通常のインターネット経由 UDP にフォールバックします。
class DataSendingService {
    private let arcService: SoracomArcServiceProtocol
    private let udpSendingService: UDPSendingService
    private let unifiedEndpointPath = "/"

    init(arcService: SoracomArcServiceProtocol) {
        self.arcService = arcService
        self.udpSendingService = UDPSendingService()
    }

    /// センサーデータを Unified Endpoint に送信する
    /// - Parameter sensorData: 送信するセンサーデータ
    /// - Returns: Arc 経由の場合はサーバーレスポンス、UDP フォールバックの場合は "(UDP フォールバック)"
    @discardableResult
    func send(_ sensorData: SensorData) async throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(sensorData)

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DataSendingError.encodingFailed
        }

        // Arc 経由での送信を試みる
        do {
            return try await arcService.sendHTTP(
                path: unifiedEndpointPath,
                method: "POST",
                body: jsonString
            )
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

        // UDP フォールバック: 通常インターネット経由で uni.soracom.io:23080 に送信
        try await udpSendingService.send(jsonData)
        return "(UDP フォールバック)"
    }
}

// MARK: - Errors

enum DataSendingError: LocalizedError {
    case encodingFailed
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "センサーデータの JSON 変換に失敗しました。"
        case .sendFailed(let detail):
            return "データ送信に失敗しました: \(detail)"
        }
    }
}
