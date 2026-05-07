import Foundation

extension AppState {
    var menuTitle: String {
        connectionState.menuTitle
    }

    var menuSymbolName: String {
        connectionState.symbolName
    }

    var actionFeedbackIsFailure: Bool {
        guard let lastActionResult,
              lastActionResult.status == .failed,
              let message = lastActionResult.message
        else {
            return false
        }
        return message == actionFeedbackMessage
    }

    var actionInboxNotifications: [LocalNotificationSummary] {
        AppActionProjection.actionInboxNotifications(
            lastNotificationSummary: lastNotificationSummary,
            transientNotifications: transientNotifications,
            recentNotifications: recentNotifications,
            actionResultsById: actionResultsById
        )
    }

    var historyNotifications: [LocalNotificationSummary] {
        recentNotifications.filter {
            $0.routesToHistory && !$0.isSharedFileReceipt
        }
    }

    var recentActivityNotifications: [LocalNotificationSummary] {
        AppActionProjection.recentActivityNotifications(
            lastNotificationSummary: lastNotificationSummary,
            transientNotifications: transientNotifications,
            recentNotifications: recentNotifications,
            actionResultsById: actionResultsById,
            now: Int64(Date().timeIntervalSince1970 * 1000)
        )
    }

    var recentSharedFileNotifications: [LocalNotificationSummary] {
        recentNotifications.filter {
            $0.isSharedFileReceipt
        }
    }

    var recentSharedFileDeliveryGroups: [SharedFileDeliveryGroup] {
        SharedFileDeliveryGroup.visibleGroups(
            from: recentSharedFileNotifications,
            activeReceiveStatus: sharedFileReceiveStatus
        )
    }

    var pairingTokenExpiresDate: Date? {
        guard let pairingTokenExpiresAt else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(pairingTokenExpiresAt) / 1000)
    }

    var sharedFileSaveDirectoryURL: URL? {
        guard let sharedFileSaveDirectoryPath, !sharedFileSaveDirectoryPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: sharedFileSaveDirectoryPath, isDirectory: true)
    }

    var effectiveSharedFileSaveDirectoryURL: URL {
        sharedFileSaveDirectoryURL ?? SharedFileStore.defaultDirectoryURL()
    }

    var sharedFileSaveDirectoryDisplayText: String {
        sharedFileSaveDirectoryURL?.path ?? "\(SharedFileStore.defaultDirectoryURL().path)（默认）"
    }

    var qrPayloadPreview: String {
        guard let pairingToken else {
            return "接力服务未启动，暂无二维码内容。"
        }

        let payload = """
        {
          "version": 1,
          "host": "\(currentHost)",
          "port": \(currentPort),
          "pairingToken": "\(pairingToken)",
          "pairingTokenExpiresAt": \(pairingTokenExpiresAt ?? 0),
          "displayName": "\(macDisplayName)"
        }
        """
        return payload
    }
}
