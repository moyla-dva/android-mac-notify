import Foundation

struct LocalServerRoutingState: Sendable {
    var macDeviceId: String
    var pairingTokenManager: LocalPairingTokenManager
    var sessionStore: LocalServerSessionStore
    var notificationIngestStore: LocalNotificationIngestStore
    var pairingApprovalStore: LocalPairingApprovalStore
    var sharedFileDirectoryURL: URL?

    init(
        macDeviceId: String,
        pairingTokenLifetimeMillis: Int64,
        sessionStore: LocalServerSessionStore = LocalServerSessionStore(),
        notificationIngestStore: LocalNotificationIngestStore = LocalNotificationIngestStore(),
        pairingApprovalStore: LocalPairingApprovalStore = LocalPairingApprovalStore(),
        sharedFileDirectoryURL: URL? = nil
    ) {
        self.macDeviceId = macDeviceId
        pairingTokenManager = LocalPairingTokenManager(lifetimeMillis: pairingTokenLifetimeMillis)
        self.sessionStore = sessionStore
        self.notificationIngestStore = notificationIngestStore
        self.pairingApprovalStore = pairingApprovalStore
        self.sharedFileDirectoryURL = sharedFileDirectoryURL
    }

    mutating func mutateRouteStores<Result>(
        _ body: (
            inout LocalPairingTokenManager,
            inout LocalDeviceRegistry,
            inout LocalNotificationIngestStore,
            inout LocalPairingApprovalStore
        ) throws -> Result
    ) rethrows -> Result {
        var mutablePairingTokenManager = pairingTokenManager
        var mutableDeviceRegistry = sessionStore.deviceRegistry
        var mutableNotificationIngestStore = notificationIngestStore
        var mutablePairingApprovalStore = pairingApprovalStore

        defer {
            pairingTokenManager = mutablePairingTokenManager
            sessionStore.deviceRegistry = mutableDeviceRegistry
            notificationIngestStore = mutableNotificationIngestStore
            pairingApprovalStore = mutablePairingApprovalStore
        }

        return try body(
            &mutablePairingTokenManager,
            &mutableDeviceRegistry,
            &mutableNotificationIngestStore,
            &mutablePairingApprovalStore
        )
    }
}
