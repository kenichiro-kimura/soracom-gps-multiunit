import Foundation

/// メタデータサービスから取得したデバイス設定
public struct MetadataConfig: Codable, Equatable, Sendable {
    /// 自動送信の有効/無効
    public let autoSend: Bool
    /// 自動送信間隔 (秒)
    public let sendingInterval: Int
    /// GPS データを送信するか
    public let sendLocation: Bool

    public init(autoSend: Bool = true, sendingInterval: Int = 60, sendLocation: Bool = true) {
        self.autoSend = autoSend
        self.sendingInterval = sendingInterval
        self.sendLocation = sendLocation
    }
}

/// メタデータサービスのsubscriber情報
public struct SubscriberMetadata: Codable, Sendable {
    public let imsi: String?
    public let msisdn: String?
    public let operatorId: String?
    public let groupId: String?

    public init(imsi: String? = nil, msisdn: String? = nil,
                operatorId: String? = nil, groupId: String? = nil) {
        self.imsi = imsi
        self.msisdn = msisdn
        self.operatorId = operatorId
        self.groupId = groupId
    }
}
