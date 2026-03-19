import Foundation

/// SORACOM Unified Endpoint にセンサーデータを送信するサービス
///
/// SORACOM Arc VPN 経由で Unified Endpoint (uni.soracom.io) にデータを送信します。
class DataSendingService {
    private let arcService: SoracomArcServiceProtocol
    private let unifiedEndpointPath = "/"

    init(arcService: SoracomArcServiceProtocol) {
        self.arcService = arcService
    }

    /// センサーデータを Unified Endpoint に送信する
    /// - Parameter sensorData: 送信するセンサーデータ
    /// - Returns: サーバーのレスポンス文字列
    @discardableResult
    func send(_ sensorData: SensorData) async throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData = try encoder.encode(sensorData)

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DataSendingError.encodingFailed
        }

        let response = try await arcService.sendHTTP(
            path: unifiedEndpointPath,
            method: "POST",
            body: jsonString
        )

        return response
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
