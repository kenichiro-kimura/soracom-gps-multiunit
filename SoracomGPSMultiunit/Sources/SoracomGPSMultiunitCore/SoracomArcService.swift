import Foundation

/// SORACOM Arc (libsoratun) に関するエラー
public enum SoracomArcError: LocalizedError, Sendable {
    case notConfigured
    case invalidConfiguration(String)
    case sendFailed(String)
    case libraryUnavailable

    public var errorDescription: String? {
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
public protocol SoracomArcServiceProtocol: AnyObject, Sendable {
    /// Arc 接続が設定済みか
    var isConfigured: Bool { get }

    /// Arc 設定を行う
    func configure(with arcConfigJSON: String) throws

    /// HTTP リクエストを Arc 経由で送信する
    func sendHTTP(path: String, method: String, body: String) async throws -> String
}

// MARK: - LibsoratunArcService

/// libsoratun C ライブラリを使った SORACOM Arc サービス実装
///
/// iOS で使用するには、libsoratun を iOS 向けにビルドして
/// libsoratun.xcframework としてプロジェクトに追加する必要があります。
public final class LibsoratunArcService: SoracomArcServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _arcConfigJSON: String?

    private var arcConfigJSON: String? {
        get { lock.withLock { _arcConfigJSON } }
        set { lock.withLock { _arcConfigJSON = newValue } }
    }

    public var isConfigured: Bool {
        guard let config = arcConfigJSON, !config.isEmpty else { return false }
        return true
    }

    public init() {}

    public func configure(with arcConfigJSON: String) throws {
        let trimmed = arcConfigJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SoracomArcError.notConfigured
        }
        guard let data = trimmed.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw SoracomArcError.invalidConfiguration("JSON として解析できません")
        }
        self.arcConfigJSON = trimmed
    }

    public func sendHTTP(path: String, method: String, body: String) async throws -> String {
        guard arcConfigJSON != nil else {
            throw SoracomArcError.notConfigured
        }
        // NOTE: libsoratun.xcframework が追加されている場合に実際の送信を行う
        throw SoracomArcError.libraryUnavailable
    }
}

// MARK: - MockArcService (開発・テスト用)

/// 開発・テスト用のモック SORACOM Arc サービス
public final class MockArcService: SoracomArcServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _isConfigured: Bool = true
    private var _shouldFail: Bool = false
    private var _mockResponse: String = "{\"result\": \"ok\"}"

    public var isConfigured: Bool {
        get { lock.withLock { _isConfigured } }
        set { lock.withLock { _isConfigured = newValue } }
    }
    public var shouldFail: Bool {
        get { lock.withLock { _shouldFail } }
        set { lock.withLock { _shouldFail = newValue } }
    }
    public var mockResponse: String {
        get { lock.withLock { _mockResponse } }
        set { lock.withLock { _mockResponse = newValue } }
    }

    public init() {}

    public func configure(with arcConfigJSON: String) throws {
        // モックなので何もしない
    }

    public func sendHTTP(path: String, method: String, body: String) async throws -> String {
        let fail = shouldFail
        let response = mockResponse
        if fail {
            throw SoracomArcError.sendFailed("モックエラー")
        }
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        return response
    }
}
