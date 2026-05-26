import Foundation
import Network

/// SORACOM Unified Endpoint に UDP で直接データを送信するサービス
///
/// SORACOM Arc が利用できない場合のフォールバックとして使用します。
/// 通常のインターネット経由で uni.soracom.io:23080 に UDP パケットを送信します。
class UDPSendingService {
    static let unifiedEndpointHost = "uni.soracom.io"
    static let unifiedEndpointPort: UInt16 = 23080
    /// UDP 通信のタイムアウト（秒）
    static let udpTimeout: TimeInterval = 10.0

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let connection = NWConnection(
                host: NWEndpoint.Host(Self.unifiedEndpointHost),
                port: NWEndpoint.Port(rawValue: Self.unifiedEndpointPort)!,
                using: .udp
            )

            // 複数回 resume しないよう NSLock でガード
            let lock = NSLock()
            var didResume = false

            func resumeOnce(_ result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // タイムアウト設定
            let timeoutWork = DispatchWorkItem {
                connection.cancel()
                resumeOnce(.failure(UDPSendingError.timeout))
            }
            DispatchQueue.global(qos: .utility).asyncAfter(
                deadline: .now() + Self.udpTimeout,
                execute: timeoutWork
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            timeoutWork.cancel()
                            connection.cancel()
                            resumeOnce(.failure(UDPSendingError.sendFailed(error.localizedDescription)))
                            return
                        }
                        // レスポンスを受信してチェックする
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, _, receiveError in
                            timeoutWork.cancel()
                            connection.cancel()
                            if let receiveError = receiveError {
                                resumeOnce(.failure(UDPSendingError.receiveFailed(receiveError.localizedDescription)))
                                return
                            }
                            guard let responseData = content, !responseData.isEmpty else {
                                resumeOnce(.failure(UDPSendingError.invalidResponse("レスポンスが空でした")))
                                return
                            }
                            // 先頭バイトが '2' (0x32) で始まらない場合は通信エラー
                            guard responseData[0] == 0x32 else {
                                let responseStr = String(data: responseData, encoding: .utf8) ?? responseData.map { String(format: "%02x", $0) }.joined()
                                resumeOnce(.failure(UDPSendingError.invalidResponse("不正なレスポンス: \(responseStr)")))
                                return
                            }
                            resumeOnce(.success(()))
                        }
                    })
                case .failed(let error):
                    timeoutWork.cancel()
                    resumeOnce(.failure(UDPSendingError.connectionFailed(error.localizedDescription)))
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))
        }
    }
}

// MARK: - Errors

enum UDPSendingError: LocalizedError {
    case connectionFailed(String)
    case sendFailed(String)
    case receiveFailed(String)
    case invalidResponse(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let detail):
            return "UDP 接続に失敗しました: \(detail)"
        case .sendFailed(let detail):
            return "UDP 送信に失敗しました: \(detail)"
        case .receiveFailed(let detail):
            return "UDP レスポンス受信に失敗しました: \(detail)"
        case .invalidResponse(let detail):
            return "UDP レスポンスが不正です: \(detail)"
        case .timeout:
            return "UDP 通信がタイムアウトしました"
        }
    }
}
