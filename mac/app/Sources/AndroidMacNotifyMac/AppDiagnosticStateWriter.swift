import Foundation

struct AppDiagnosticStateSnapshot {
    let connectionState: ConnectionState
    let currentHost: String
    let currentPort: Int
    let pairingToken: String?
    let pairingTokenExpiresAt: Int64?
    let macDeviceId: String?
    let macDisplayName: String
    let pairedDeviceName: String?
    let statusCard: StatusCardState?
    let sharedFileReceiveStatus: SharedFileReceiveStatus?
    let recentStatusCards: [StatusCardState]
    let pendingPairingRequests: [PairingApprovalRequest]
    let notificationsReceived: Int
    let actionFeedbackMessage: String?
    let lastActionResult: ActionResult?
    let actionResults: [ActionResult]
    let lastNotificationSummary: LocalNotificationSummary?
    let transientNotifications: [LocalNotificationSummary]
    let lastError: String?
}

struct AppDiagnosticStateWriter {
    private let directoryURL: URL?

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
    }

    func write(_ snapshot: AppDiagnosticStateSnapshot) -> String? {
        let url: URL
        do {
            url = try diagnosticStateURL()
        } catch {
            return "Failed to prepare diagnostics: \(error.localizedDescription)"
        }
        try? FileManager.default.removeItem(atPath: "/tmp/android-mac-notify-runtime.json")

        let payload = diagnosticPayload(for: snapshot)
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        else {
            return nil
        }

        do {
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return nil
        } catch {
            return "Failed to write diagnostics: \(error.localizedDescription)"
        }
    }

    private func diagnosticStateURL() throws -> URL {
        let fileManager = FileManager.default
        let baseURL = directoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        var directoryURL = baseURL.appendingPathComponent("Android Mac Notify", isDirectory: true)

        if self.directoryURL != nil {
            directoryURL = baseURL
        }

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? directoryURL.setResourceValues(resourceValues)
        return directoryURL.appendingPathComponent("runtime-diagnostics.json", isDirectory: false)
    }

    private func diagnosticPayload(for snapshot: AppDiagnosticStateSnapshot) -> [String: Any] {
        [
            "connectionState": snapshot.connectionState.title,
            "host": snapshot.currentHost,
            "port": snapshot.currentPort,
            "pairingTokenPresent": snapshot.pairingToken != nil,
            "pairingTokenExpiresAt": optional(snapshot.pairingTokenExpiresAt),
            "macDeviceId": optional(snapshot.macDeviceId),
            "macDisplayName": snapshot.macDisplayName,
            "pairedDeviceName": optional(snapshot.pairedDeviceName),
            "statusCard": optional(snapshot.statusCard.map(statusCardPayload)),
            "sharedFileReceiveStatus": optional(snapshot.sharedFileReceiveStatus.map(sharedFileReceiveStatusPayload)),
            "statusCardHistory": snapshot.recentStatusCards.map(statusCardPayload),
            "pendingPairingRequests": snapshot.pendingPairingRequests.map(pairingRequestPayload),
            "notificationsReceived": snapshot.notificationsReceived,
            "actionFeedbackMessageLength": optional(snapshot.actionFeedbackMessage?.count),
            "lastActionResult": optional(snapshot.lastActionResult.map(actionResultPayload)),
            "actionResults": snapshot.actionResults
                .sorted { $0.executedAt > $1.executedAt }
                .map(actionResultPayload),
            "lastNotification": optional(snapshot.lastNotificationSummary.map(notificationPayload)),
            "transientNotifications": snapshot.transientNotifications.map(transientNotificationPayload),
            "lastError": optional(snapshot.lastError),
        ]
    }

    private func statusCardPayload(for card: StatusCardState) -> [String: Any] {
        [
            "id": card.id,
            "category": card.category.rawValue,
            "sourceEventId": card.sourceEventId,
            "appName": card.appName,
            "titleLength": card.title.count,
            "detailLength": card.detail.count,
            "stage": card.stage.rawValue,
            "etaText": optional(card.etaText),
            "updatedAt": card.updatedAt,
        ]
    }

    private func sharedFileReceiveStatusPayload(for status: SharedFileReceiveStatus) -> [String: Any] {
        [
            "transferId": status.transferId,
            "batchId": optional(status.batchId),
            "batchIndex": optional(status.batchIndex),
            "batchTotal": optional(status.batchTotal),
            "fileNameLength": status.fileName.count,
            "receivedBytes": status.receivedBytes,
            "totalBytes": status.totalBytes,
            "speedBytesPerSecond": optional(status.speedBytesPerSecond),
            "remainingSeconds": optional(status.remainingSeconds),
            "stage": status.stage.rawValue,
            "messageLength": optional(status.message?.count),
            "updatedAt": status.updatedAt,
        ]
    }

    private func pairingRequestPayload(for request: PairingApprovalRequest) -> [String: Any] {
        [
            "requestId": request.requestId,
            "deviceId": request.device.deviceId,
            "displayName": request.device.displayName,
            "requestedAt": request.requestedAt,
            "expiresAt": request.expiresAt,
            "status": request.status.rawValue,
        ]
    }

    private func actionResultPayload(for result: ActionResult) -> [String: Any] {
        [
            "actionId": result.actionId,
            "sourceEventId": result.sourceEventId,
            "status": result.status.rawValue,
            "executedAt": result.executedAt,
            "messageLength": optional(result.message?.count),
        ]
    }

    private func transientNotificationPayload(for summary: LocalNotificationSummary) -> [String: Any] {
        [
            "appPackage": optional(summary.appPackage),
            "appName": summary.appName,
            "receivedAt": summary.receivedAt,
            "visibleActions": summary.visibleActionCandidates.map(visibleActionPayload),
            "ruleReasons": summary.ruleDecision.reasonCodes,
            "defaultActionId": optional(summary.ruleDecision.defaultActionId),
            "primarySurface": summary.ruleDecision.primarySurface.rawValue,
            "secondarySurfaces": summary.ruleDecision.secondarySurfaces.map(\.rawValue),
            "interruptionLevel": summary.ruleDecision.interruptionLevel.rawValue,
            "persistencePolicy": summary.ruleDecision.persistencePolicy.rawValue,
            "privacyLevel": summary.ruleDecision.privacyLevel.rawValue,
        ]
    }

    private func notificationPayload(for summary: LocalNotificationSummary) -> [String: Any] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let isPersisted = NotificationHistoryPolicy.shouldPersist(summary, now: now)
        var payload: [String: Any] = [
            "appPackage": optional(summary.appPackage),
            "appName": summary.appName,
            "receivedAt": summary.receivedAt,
            "isTransient": !isPersisted,
            "visibleActions": summary.visibleActionCandidates.map { action in
                var actionPayload = visibleActionPayload(for: action)
                actionPayload["hasValue"] = action.value?.isEmpty == false
                return actionPayload
            },
            "ruleReasons": summary.ruleDecision.reasonCodes,
            "defaultActionId": optional(summary.ruleDecision.defaultActionId),
            "primarySurface": summary.ruleDecision.primarySurface.rawValue,
            "secondarySurfaces": summary.ruleDecision.secondarySurfaces.map(\.rawValue),
            "interruptionLevel": summary.ruleDecision.interruptionLevel.rawValue,
            "persistencePolicy": summary.ruleDecision.persistencePolicy.rawValue,
            "privacyLevel": summary.ruleDecision.privacyLevel.rawValue,
        ]

        if isPersisted {
            payload["titleLength"] = summary.title.count
            payload["textLength"] = summary.text.count
            payload["hasVerificationCode"] = summary.verificationCode != nil
            payload["hasVerificationSenderLabel"] = summary.verificationSenderLabel?.isEmpty == false
        }

        return payload
    }

    private func visibleActionPayload(for action: ActionCandidate) -> [String: Any] {
        [
            "actionId": action.actionId,
            "kind": action.kind.rawValue,
            "title": action.title,
            "priority": action.priority.rawValue,
        ]
    }

    private func optional<T>(_ value: T?) -> Any {
        value ?? NSNull()
    }
}
