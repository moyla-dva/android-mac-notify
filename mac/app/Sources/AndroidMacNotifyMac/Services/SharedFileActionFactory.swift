import Foundation

enum SharedFileActionFactory {
    static func summary(from receipt: SharedFileReceipt) -> LocalNotificationSummary {
        let eventId = "shared_file_\(receipt.shareId)"
        let actions = actionCandidates(for: receipt, eventId: eventId)
        let visibleActionIds = actions.map(\.actionId)
        var reasonCodes = [
            "shared_file_received",
            "file_saved_to_mac_directory",
        ]
        if receipt.originalFileName != nil {
            reasonCodes.append("shared_file_saved_with_new_name")
        }
        if let batchId = receipt.batchId, !batchId.isEmpty {
            reasonCodes.append("shared_file_batch_id:\(batchId)")
        }
        if let batchIndex = receipt.batchIndex {
            reasonCodes.append("shared_file_batch_index:\(batchIndex)")
        }
        if let batchTotal = receipt.batchTotal {
            reasonCodes.append("shared_file_batch_total:\(batchTotal)")
        }

        return LocalNotificationSummary(
            eventId: eventId,
            deviceId: receipt.deviceId,
            appPackage: "android_mac_notify.shared_file",
            appName: "Android Mac Notify",
            title: receipt.fileName,
            text: "\(formattedSize(receipt.size)) · \(receipt.savedPath)",
            receivedAt: receipt.receivedAt,
            verificationContext: nil,
            actionCandidates: actions,
            ruleDecision: RuleDecision(
                shouldPresentSystemNotification: false,
                historyPolicy: .record,
                visibleActionIds: visibleActionIds,
                defaultActionId: actions.first(where: { $0.kind == .openFile })?.actionId,
                reasonCodes: reasonCodes,
                primarySurface: .history,
                secondarySurfaces: [],
                interruptionLevel: .passive,
                persistencePolicy: .record,
                privacyLevel: .standard
            )
        )
    }

    private static func actionCandidates(for receipt: SharedFileReceipt, eventId: String) -> [ActionCandidate] {
        [
            ActionCandidate(
                actionId: actionId(eventId, "open-file"),
                sourceEventId: eventId,
                kind: .openFile,
                title: "打开文件",
                value: receipt.savedPath,
                priority: .high,
                payload: .file(path: receipt.savedPath, fileName: receipt.fileName, mimeType: nil)
            ),
            ActionCandidate(
                actionId: actionId(eventId, "reveal-file"),
                sourceEventId: eventId,
                kind: .revealFile,
                title: "在 Finder 中显示",
                value: receipt.savedPath,
                priority: .medium,
                payload: .file(path: receipt.savedPath, fileName: receipt.fileName, mimeType: nil)
            ),
            ActionCandidate(
                actionId: actionId(eventId, "copy-file-path"),
                sourceEventId: eventId,
                kind: .copyFilePath,
                title: "复制路径",
                value: receipt.savedPath,
                priority: .low,
                payload: .file(path: receipt.savedPath, fileName: receipt.fileName, mimeType: nil)
            ),
        ]
    }

    private static func actionId(_ eventId: String, _ suffix: String) -> String {
        "act_\(eventId)_\(suffix)"
    }

    private static func formattedSize(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

extension LocalNotificationSummary {
    var sharedFileBatchId: String? {
        reasonCodeValue(prefix: "shared_file_batch_id:")
    }

    var sharedFileBatchIndex: Int? {
        reasonCodeValue(prefix: "shared_file_batch_index:").flatMap(Int.init)
    }

    var sharedFileBatchTotal: Int? {
        reasonCodeValue(prefix: "shared_file_batch_total:").flatMap(Int.init)
    }

    var sharedFileWasSavedWithNewName: Bool {
        ruleDecision.reasonCodes.contains("shared_file_saved_with_new_name")
    }

    private func reasonCodeValue(prefix: String) -> String? {
        ruleDecision.reasonCodes
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
