import Foundation

/// SORACOM Unified Endpoint にセンサーデータを送信するサービス
public final class DataSendingService: Sendable {
    private let arcService: any SoracomArcServiceProtocol
    private let unifiedEndpointPath = "/"

    public init(arcService: any SoracomArcServiceProtocol) {
        self.arcService = arcService
    }

    /// センサーデータを Unified Endpoint に送信する
    @discardableResult
    public func send(_ sensorData: SensorData) async throws -> String {
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

public enum DataSendingError: LocalizedError, Sendable {
    case encodingFailed
    case sendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "センサーデータの JSON 変換に失敗しました。"
        case .sendFailed(let detail):
            return "データ送信に失敗しました: \(detail)"
        }
    }
}
