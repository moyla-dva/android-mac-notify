import Foundation

struct AppLocalServerSnapshotProjection: Equatable {
    let currentHost: String
    let currentPort: Int
    let pairingToken: String
    let pairingTokenExpiresAt: Int64
    let macDeviceId: String
    let macDisplayName: String
    let serverStatus: ServerStatus
    let registeredDevices: [LocalRegisteredDevice]
    let recentNotifications: [LocalNotificationSummary]
    let transientNotifications: [LocalNotificationSummary]
    let transientActionSummaries: [String: LocalNotificationSummary]
    let lastNotificationSummary: LocalNotificationSummary?
    let notificationsReceived: Int
    let pairedDeviceName: String?
    let connectionState: ConnectionState
}

struct AppLocalServerStoppedProjection: Equatable {
    let serverStatus: ServerStatus
    let isReceiverPaused: Bool
    let pairingToken: String?
    let pairingTokenExpiresAt: Int64?
    let connectionState: ConnectionState
    let sharedFileReceiveStatus: SharedFileReceiveStatus?
}

struct AppLocalServerFailureProjection: Equatable {
    let lastError: String
    let serverStatus: ServerStatus
    let connectionState: ConnectionState
}

enum AppLocalServerRuntimeProjector {
    static func snapshot(
        _ snapshot: LocalServerSnapshot,
        isReceiverPaused: Bool,
        now: Int64,
        connectionStateProjector: AppConnectionStateProjector
    ) -> AppLocalServerSnapshotProjection {
        let recentNotifications = NotificationHistoryPolicy.visibleSummaries(
            from: snapshot.recentNotifications,
            now: now
        )
        let connectionProjection = connectionStateProjector.project(
            devices: snapshot.registeredDevices,
            isReceiverPaused: isReceiverPaused,
            now: now
        )

        return AppLocalServerSnapshotProjection(
            currentHost: snapshot.endpoint.host,
            currentPort: snapshot.endpoint.port,
            pairingToken: snapshot.pairingToken,
            pairingTokenExpiresAt: snapshot.pairingTokenExpiresAt,
            macDeviceId: snapshot.macDeviceId,
            macDisplayName: snapshot.macDisplayName,
            serverStatus: .running(host: snapshot.endpoint.host, port: snapshot.endpoint.port),
            registeredDevices: snapshot.registeredDevices,
            recentNotifications: recentNotifications,
            transientNotifications: [],
            transientActionSummaries: [:],
            lastNotificationSummary: recentNotifications.first,
            notificationsReceived: snapshot.recentNotifications.count,
            pairedDeviceName: connectionProjection.pairedDeviceName,
            connectionState: connectionProjection.connectionState
        )
    }

    static func stopped(pairedDeviceName: String?) -> AppLocalServerStoppedProjection {
        let connectionState: ConnectionState
        if let pairedDeviceName {
            connectionState = .macReceiverPaused(deviceName: pairedDeviceName)
        } else {
            connectionState = .unpaired
        }

        return AppLocalServerStoppedProjection(
            serverStatus: .stopped,
            isReceiverPaused: false,
            pairingToken: nil,
            pairingTokenExpiresAt: nil,
            connectionState: connectionState,
            sharedFileReceiveStatus: nil
        )
    }

    static func failed(message: String) -> AppLocalServerFailureProjection {
        AppLocalServerFailureProjection(
            lastError: message,
            serverStatus: .failed(message: message),
            connectionState: .networkUnavailable
        )
    }
}
