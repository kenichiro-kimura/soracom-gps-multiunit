import Foundation

/// メタデータサービスから取得したデバイス設定
struct MetadataConfig: Codable, Equatable {
    /// 自動送信の有効/無効
    let autoSend: Bool
    /// 自動送信間隔 (秒)
    let sendingInterval: Int
    /// GPS データを送信するか
    let sendLocation: Bool

    init(autoSend: Bool = true, sendingInterval: Int = 60, sendLocation: Bool = true) {
        self.autoSend = autoSend
        self.sendingInterval = sendingInterval
        self.sendLocation = sendLocation
    }
}

/// メタデータサービスのsubscriber情報
struct SubscriberMetadata: Codable {
    let imsi: String?
    let msisdn: String?
    let operatorId: String?
    let groupId: String?
}
