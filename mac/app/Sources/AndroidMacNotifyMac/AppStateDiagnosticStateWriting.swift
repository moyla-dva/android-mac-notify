import Foundation

extension AppState {
    func writeDiagnosticState() {
        let now = Date()
        if let lastDiagnosticStateWriteAt {
            let elapsed = now.timeIntervalSince(lastDiagnosticStateWriteAt)
            if elapsed < diagnosticStateWriteInterval {
                scheduleDiagnosticStateWrite(after: diagnosticStateWriteInterval - elapsed)
                return
            }
        }

        writeDiagnosticStateNow()
    }

    private var diagnosticStateWriteInterval: TimeInterval {
        1.0
    }

    private func scheduleDiagnosticStateWrite(after delay: TimeInterval) {
        guard pendingDiagnosticStateWriteTask == nil else {
            return
        }

        pendingDiagnosticStateWriteTask = Task { [weak self] in
            let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }

            await MainActor.run {
                guard let self else {
                    return
                }
                self.pendingDiagnosticStateWriteTask = nil
                self.writeDiagnosticStateNow()
            }
        }
    }

    private func writeDiagnosticStateNow() {
        pendingDiagnosticStateWriteTask?.cancel()
        pendingDiagnosticStateWriteTask = nil
        lastDiagnosticStateWriteAt = Date()

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
