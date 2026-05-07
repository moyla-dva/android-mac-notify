import Foundation

enum LocalServerEvent: Sendable {
    case serverStarted(LocalServerSnapshot)
    case serverStopped
    case pairingTokenUpdated(LocalServerSnapshot)
    case pairingApprovalRequested(PairingApprovalRequest)
    case pairingApprovalUpdated(PairingApprovalRequest)
    case deviceRegistered(LocalRegisteredDevice)
    case heartbeat(deviceId: String, at: Int64)
    case deviceSessionUpdated(LocalRegisteredDevice)
    case deviceUnregistered(deviceId: String)
    case notificationAccepted(LocalNotificationSummary)
    case sharedText(deviceId: String, text: String, sharedAt: Int64)
    case sharedFileTransferUpdated(SharedFileReceiveStatus)
    case sharedFile(SharedFileReceipt)
    case serverFailed(String)
}
