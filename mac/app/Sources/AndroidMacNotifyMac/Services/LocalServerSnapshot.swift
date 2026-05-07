import Foundation

struct LocalServerSnapshot: Equatable, Sendable {
    let endpoint: LocalServerEndpoint
    let pairingToken: String
    let pairingTokenExpiresAt: Int64
    let macDeviceId: String
    let macDisplayName: String
    let pairedDeviceCount: Int
    let registeredDevices: [LocalRegisteredDevice]
    let recentNotifications: [LocalNotificationSummary]
}
