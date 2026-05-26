import Foundation
import Network

/// SORACOM Unified Endpoint に UDP で直接データを送信するサービス
///
/// SORACOM Arc が利用できない場合のフォールバックとして使用します。
/// 通常のインターネット経由で uni.soracom.io:23080 に UDP パケットを送信します。
class UDPSendingService {
    static let unifiedEndpointHost = "uni.soracom.io"
    static let unifiedEndpointPort: UInt16 = 23080

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

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        connection.cancel()
                        if let error = error {
                            resumeOnce(.failure(UDPSendingError.sendFailed(error.localizedDescription)))
                        } else {
                            resumeOnce(.success(()))
                        }
                    })
                case .failed(let error):
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

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let detail):
            return "UDP 接続に失敗しました: \(detail)"
        case .sendFailed(let detail):
            return "UDP 送信に失敗しました: \(detail)"
        }
    }
}
