import Foundation

extension AppState {
    func writeDiagnosticState() {
        let snapshot = AppDiagnosticStateSnapshot(
            connectionState: connectionState,
            currentHost: currentHost,
            currentPort: currentPort,
            pairingToken: pairingToken,
            pairingTokenExpiresAt: pairingTokenExpiresAt,
            macDeviceId: macDeviceId,
            macDisplayName: macDisplayName,
            pairedDeviceName: pairedDeviceName,
            statusCard: statusCard,
            sharedFileReceiveStatus: sharedFileReceiveStatus,
            recentStatusCards: recentStatusCards,
            pendingPairingRequests: pendingPairingRequests,
            notificationsReceived: notificationsReceived,
            actionFeedbackMessage: actionFeedbackMessage,
            lastActionResult: lastActionResult,
            actionResults: Array(actionResultsById.values),
            lastNotificationSummary: lastNotificationSummary,
            transientNotifications: transientNotifications,
            lastError: lastError
        )
        if let message = diagnosticStateWriter.write(snapshot) {
            lastError = message
        }
    }
}
