import Foundation

extension AppState {
    func handle(serverEvent: LocalServerEvent) {
        switch serverEvent {
        case let .serverStarted(snapshot):
            apply(snapshot: snapshot)
            print(
                """
                [AndroidMacNotifyMac] local server ready
                host=\(snapshot.endpoint.host)
                port=\(snapshot.endpoint.port)
                pairingToken=\(snapshot.pairingToken)
                macDeviceId=\(snapshot.macDeviceId)
                """
            )
            writeDiagnosticState()

        case let .pairingTokenUpdated(snapshot):
            apply(snapshot: snapshot)
            writeDiagnosticState()

        case let .pairingApprovalRequested(request):
            apply(
                pairingApprovalProjection: AppPairingApprovalProjector.project(
                    request: request,
                    currentPendingRequests: pendingPairingRequests
                )
            )
            writeDiagnosticState()
            presentPairingApprovalAlertIfNeeded(for: request)

        case let .pairingApprovalUpdated(request):
            apply(
                pairingApprovalProjection: AppPairingApprovalProjector.project(
                    request: request,
                    currentPendingRequests: pendingPairingRequests
                )
            )
            writeDiagnosticState()

        case .serverStopped:
            applyLocalServerStopped()
            writeDiagnosticState()

        case let .deviceRegistered(device):
            apply(
                deviceSessionProjection: AppDeviceSessionProjector.registered(
                    device: device,
                    existingDevices: registeredDevices,
                    isReceiverPaused: isReceiverPaused,
                    now: nowMillis(),
                    connectionStateProjector: connectionStateProjector
                )
            )
            clearNetworkUnavailableErrorIfNeeded()
            print("[AndroidMacNotifyMac] paired device registered: \(device.displayName) (\(device.deviceId))")
            writeDiagnosticState()

        case let .heartbeat(deviceId, at):
            apply(
                deviceSessionProjection: AppDeviceSessionProjector.heartbeat(
                    deviceId: deviceId,
                    at: at,
                    existingDevices: registeredDevices,
                    currentPairedDeviceName: pairedDeviceName,
                    currentConnectionState: connectionState,
                    isReceiverPaused: isReceiverPaused,
                    connectionStateProjector: connectionStateProjector
                )
            )
            clearNetworkUnavailableErrorIfNeeded()
            writeDiagnosticState()

        case let .deviceSessionUpdated(device):
            apply(
                deviceSessionProjection: AppDeviceSessionProjector.registered(
                    device: device,
                    existingDevices: registeredDevices,
                    isReceiverPaused: isReceiverPaused,
                    now: nowMillis(),
                    connectionStateProjector: connectionStateProjector
                )
            )
            clearNetworkUnavailableErrorIfNeeded()
            writeDiagnosticState()

        case let .deviceUnregistered(deviceId):
            apply(
                deviceSessionProjection: AppDeviceSessionProjector.unregistered(
                    deviceId: deviceId,
                    existingDevices: registeredDevices,
                    isReceiverPaused: isReceiverPaused,
                    now: nowMillis(),
                    connectionStateProjector: connectionStateProjector
                )
            )
            writeDiagnosticState()

        case let .notificationAccepted(summary):
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            apply(
                notificationEventProjection: AppNotificationEventProjector.accepted(
                    summary: summary,
                    currentNotificationsReceived: notificationsReceived,
                    recentNotifications: recentNotifications,
                    transientActionSummaries: transientActionSummaries,
                    now: now
                )
            )
            updateStatusCardIfNeeded(from: summary)
            markConnectedIfPairedDeviceExists()
            clearNetworkUnavailableErrorIfNeeded()
            print("[AndroidMacNotifyMac] notification accepted: \(summary.appName) \(summary.title)")
            writeDiagnosticState()
            publishActionPromptIfNeeded(for: summary)

        case .sharedText:
            break

        case let .sharedFileTransferUpdated(status):
            apply(
                sharedFileTransferProjection: AppSharedFileEventProjector.transferUpdated(
                    status: status
                )
            )
            if status.stage == .receiving {
                markConnectedIfPairedDeviceExists()
                clearNetworkUnavailableErrorIfNeeded()
            }
            writeDiagnosticState()

        case let .sharedFile(receipt):
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let projection = AppSharedFileEventProjector.received(
                receipt: receipt,
                currentNotificationsReceived: notificationsReceived,
                recentNotifications: recentNotifications,
                transientActionSummaries: transientActionSummaries,
                now: now
            )
            apply(sharedFileReceiptProjection: projection)
            markConnectedIfPairedDeviceExists()
            clearNetworkUnavailableErrorIfNeeded()
            writeDiagnosticState()
            if AppSharedFilePromptPolicy.shouldPublishActionPrompt(for: receipt) {
                publishActionPromptIfNeeded(for: projection.summary)
            }

        case let .serverFailed(message):
            applyLocalServerFailure(message: message)
        }
    }
}
