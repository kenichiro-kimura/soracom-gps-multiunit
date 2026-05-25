import Foundation

/// SORACOM Arc (libsoratun) に関するエラー
enum SoracomArcError: LocalizedError {
    case notConfigured
    case invalidConfiguration(String)
    case sendFailed(String)
    case libraryUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "SORACOM Arc が設定されていません。設定画面から arc.json を入力してください。"
        case .invalidConfiguration(let message):
            return "設定が無効です: \(message)"
        case .sendFailed(let message):
            return "送信に失敗しました: \(message)"
        case .libraryUnavailable:
            return "libsoratun ライブラリが利用できません。"
        }
    }
}

/// SORACOM Arc 接続サービスのプロトコル
protocol SoracomArcServiceProtocol: AnyObject {
    /// Arc 接続が設定済みか
    var isConfigured: Bool { get }

    /// Arc 設定を行う
    /// - Parameter arcConfigJSON: arc.json の内容
    func configure(with arcConfigJSON: String) throws

    /// HTTP リクエストを Arc 経由で送信する
    /// - Parameters:
    ///   - path: リクエストパス
    ///   - method: HTTP メソッド ("GET" または "POST")
    ///   - body: リクエストボディ
    /// - Returns: レスポンスボディ文字列
    func sendHTTP(path: String, method: String, body: String) async throws -> String
}

// MARK: - LibsoratunArcService

/// libsoratun C ライブラリを使った SORACOM Arc サービス実装
///
/// ## 前提条件
/// このクラスを利用するには、libsoratun を iOS 向けにビルドして
/// `libsoratun.xcframework` としてプロジェクトに追加する必要があります。
///
/// ## ビルド手順
/// ```
/// git clone https://github.com/0x6b/libsoratun
/// cd libsoratun
/// # iOS 向けに gomobile またはクロスコンパイルでビルド
/// # 生成された .xcframework を Xcode プロジェクトに追加
/// ```
class LibsoratunArcService: SoracomArcServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _arcConfigJSON: String?

    private var arcConfigJSON: String? {
        get { lock.withLock { _arcConfigJSON } }
        set { lock.withLock { _arcConfigJSON = newValue } }
    }

    var isConfigured: Bool {
        guard let config = arcConfigJSON, !config.isEmpty else { return false }
        return true
    }

    func configure(with arcConfigJSON: String) throws {
        let trimmed = arcConfigJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SoracomArcError.notConfigured
        }
        // JSON として有効かチェック
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SoracomArcError.invalidConfiguration("JSON として解析できません")
        }
        // soratun 形式 → libsoratun 形式へ自動変換
        // soratun 形式: { "privateKey", "address", "publicKey", "allowedIPs", "endpoint" }
        // libsoratun 形式: { "privateKey", "arcSession": { "arcServerPeerPublicKey", ... } }
        let effectiveJSONString: String
        if json["arcSession"] == nil, json["endpoint"] is String {
            guard let converted = Self.convertSoratunFormat(json),
                  let convertedData = try? JSONSerialization.data(withJSONObject: converted),
                  let convertedString = String(data: convertedData, encoding: .utf8) else {
                throw SoracomArcError.invalidConfiguration("soratun 形式の JSON を libsoratun 形式に変換できませんでした")
            }
            effectiveJSONString = convertedString
        } else {
            effectiveJSONString = trimmed
        }

        // arcSession フィールドの存在チェック
        // libsoratun の newTunnel は config.ArcSession が nil だとクラッシュするため、
        // Swift 側で事前にチェックして分かりやすいエラーを返す
        guard let effectiveData = effectiveJSONString.data(using: .utf8),
              let effectiveJSON = try? JSONSerialization.jsonObject(with: effectiveData) as? [String: Any],
              effectiveJSON["arcSession"] is [String: Any] else {
            throw SoracomArcError.invalidConfiguration(
                "arcSession フィールドがありません。soratun の arc.json を貼り付けてください。"
            )
        }
        self.arcConfigJSON = effectiveJSONString
    }

    /// soratun 形式の JSON を libsoratun 形式に変換する
    private static func convertSoratunFormat(_ json: [String: Any]) -> [String: Any]? {
        guard let privateKey = json["privateKey"] as? String,
              let address = json["address"] as? String,
              let publicKey = json["publicKey"] as? String,
              let allowedIPs = json["allowedIPs"] as? [String],
              let endpoint = json["endpoint"] as? String else {
            return nil
        }
        // "10.217.133.173/32" → "10.217.133.173" (CIDR → IP のみ)
        let clientIP = address.components(separatedBy: "/").first ?? address
        let arcSession: [String: Any] = [
            "arcServerPeerPublicKey": publicKey,
            "arcServerEndpoint": endpoint,
            "arcAllowedIPs": allowedIPs,
            "arcClientPeerIpAddress": clientIP
        ]
        return [
            "privateKey": privateKey,
            "logLevel": 1,
            "arcSession": arcSession
        ]
    }

    func sendHTTP(path: String, method: String, body: String) async throws -> String {
        guard let config = arcConfigJSON, !config.isEmpty else {
            throw SoracomArcError.notConfigured
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                // libsoratun の C 関数を呼び出す
                // NOTE: Send() はブリッジングヘッダー経由で宣言されており、
                // Simulator・実機ともに同じコードで呼び出す
                guard let resultPtr = Send(config, method, path, body) else {
                    continuation.resume(throwing: SoracomArcError.sendFailed("レスポンスが null でした"))
                    return
                }
                let result = String(cString: resultPtr)
                free(resultPtr)
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - MockArcService (開発・テスト用)

/// 開発・テスト用のモック SORACOM Arc サービス
///
/// libsoratun が利用できない環境でのデバッグや UI 開発に使います。
/// 実際のネットワーク通信は行わず、成功レスポンスを返します。
class MockArcService: SoracomArcServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _isConfigured: Bool = true
    private var _shouldFail: Bool = false
    private var _mockResponse: String = "{\"result\": \"ok\"}"

    var isConfigured: Bool {
        get { lock.withLock { _isConfigured } }
        set { lock.withLock { _isConfigured = newValue } }
    }
    var shouldFail: Bool {
        get { lock.withLock { _shouldFail } }
        set { lock.withLock { _shouldFail = newValue } }
    }
    var mockResponse: String {
        get { lock.withLock { _mockResponse } }
        set { lock.withLock { _mockResponse = newValue } }
    }

    func configure(with arcConfigJSON: String) throws {
        // モックなので何もしない
    }

    func sendHTTP(path: String, method: String, body: String) async throws -> String {
        let fail = shouldFail
        let response = mockResponse
        if fail {
            throw SoracomArcError.sendFailed("モックエラー")
        }
        // 実際の送信をシミュレート
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        return response
    }
}
