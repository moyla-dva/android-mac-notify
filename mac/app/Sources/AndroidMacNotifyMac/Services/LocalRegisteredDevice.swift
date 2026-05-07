import Foundation

struct LocalRegisteredDevice: Codable, Equatable, Sendable {
    let deviceId: String
    let platform: String
    var displayName: String
    let deviceToken: String
    var lastSeenAt: Int64
    var relayState: RelayState?
}
