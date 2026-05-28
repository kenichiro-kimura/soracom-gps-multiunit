import Foundation

/// SORACOM メタデータサービスからデバイス設定を取得するサービス
public final class MetadataService: Sendable {
    private let arcService: any SoracomArcServiceProtocol
    private let metadataPath = "/v1/userdata"
    private let subscriberPath = "/v1/subscriber"

    public init(arcService: any SoracomArcServiceProtocol) {
        self.arcService = arcService
    }

    /// デバイス設定を取得する
    public func fetchConfig() async throws -> MetadataConfig {
        let responseBody = try await arcService.sendHTTP(
            path: metadataPath,
            method: "GET",
            body: ""
        )

        guard let data = responseBody.data(using: .utf8) else {
            throw MetadataServiceError.invalidResponse
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(MetadataConfig.self, from: data)
        } catch {
            throw MetadataServiceError.decodingFailed(error.localizedDescription)
        }
    }

    /// subscriber 情報を取得する
    public func fetchSubscriber() async throws -> SubscriberMetadata {
        let responseBody = try await arcService.sendHTTP(
            path: subscriberPath,
            method: "GET",
            body: ""
        )

        guard let data = responseBody.data(using: .utf8) else {
            throw MetadataServiceError.invalidResponse
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(SubscriberMetadata.self, from: data)
        } catch {
            throw MetadataServiceError.decodingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Errors

public enum MetadataServiceError: LocalizedError, Sendable {
    case invalidResponse
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "メタデータサービスから無効なレスポンスを受信しました。"
        case .decodingFailed(let detail):
            return "メタデータの解析に失敗しました: \(detail)"
        }
    }
}
