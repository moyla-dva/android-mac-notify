import Foundation

enum NotificationHistoryPolicy {
    static let maxStoredCount = 100
    static let maxVisibleCount = 10
    static let maxStoredAgeMillis: Int64 = 24 * 60 * 60 * 1_000
    static let maxTransientActionCount = 20
    static let maxTransientActionAgeMillis: Int64 = 10 * 60 * 1_000

    private static let transientAppIdentifiers: Set<String> = [
        "com.android.mms",
        "com.google.android.apps.messaging",
        "com.huawei.message",
        "com.tencent.mm",
        "com.tencent.mobileqq",
        "com.tencent.tim",
        "messages",
        "message",
        "短信",
        "信息",
        "微信",
        "wechat",
        "weixin",
        "qq",
        "tim",
        "telegram",
        "org.telegram.messenger",
        "org.thunderdog.challegram",
    ]

    static func shouldRecord(payload: NotificationPayload, candidates: [ActionCandidate]) -> Bool {
        if candidates.contains(where: { $0.kind == .copyVerificationCode }) {
            return false
        }

        return !isTransientAppIdentifier(payload.appPackage)
            && !isTransientAppIdentifier(payload.appName)
    }

    static func shouldPersist(_ summary: LocalNotificationSummary, now: Int64) -> Bool {
        guard isWithinRetentionWindow(summary, now: now) else {
            return false
        }

        switch summary.ruleDecision.persistencePolicy {
        case .record:
            return shouldPersistRecord(summary)
        case .skip, .transient, .stateOnly:
            return false
        }
    }

    private static func shouldPersistRecord(_ summary: LocalNotificationSummary) -> Bool {
        guard !summary.actionCandidates.contains(where: { $0.kind == .copyVerificationCode }) else {
            return false
        }
        if summary.ruleDecision.reasonCodes.contains("low_value_history_only") {
            return true
        }
        return !isTransientAppIdentifier(summary.appPackage)
            && !isTransientAppIdentifier(summary.appName)
    }

    static func storedSummaries(from summaries: [LocalNotificationSummary], now: Int64) -> [LocalNotificationSummary] {
        Array(summaries.filter { shouldPersist($0, now: now) }.prefix(maxStoredCount))
    }

    static func visibleSummaries(from summaries: [LocalNotificationSummary], now: Int64) -> [LocalNotificationSummary] {
        Array(storedSummaries(from: summaries, now: now).prefix(maxVisibleCount))
    }

    static func transientActionSummaries(
        from summaries: [LocalNotificationSummary],
        now: Int64
    ) -> [LocalNotificationSummary] {
        Array(
            summaries
                .filter { shouldKeepTransientActionSummary($0, now: now) }
                .sorted { $0.receivedAt > $1.receivedAt }
                .prefix(maxTransientActionCount)
        )
    }

    static func shouldKeepTransientActionSummary(_ summary: LocalNotificationSummary, now: Int64) -> Bool {
        guard !shouldPersist(summary, now: now) else {
            return false
        }
        guard isWithinTransientActionWindow(summary, now: now) else {
            return false
        }
        return summary.actionCandidates.contains { action in
            action.isUserVisible && shouldExpose(action: action, for: summary)
        }
    }

    static func shouldExpose(action: ActionCandidate, for summary: LocalNotificationSummary) -> Bool {
        switch action.kind {
        case .copyText:
            return isTransientAppIdentifier(summary.appPackage)
                || isTransientAppIdentifier(summary.appName)
        case .showNotification, .copyVerificationCode, .openLink, .openFile, .revealFile, .copyFilePath, .recordHistory:
            return true
        }
    }

    private static func isWithinRetentionWindow(_ summary: LocalNotificationSummary, now: Int64) -> Bool {
        guard summary.receivedAt <= now else {
            return true
        }
        return now - summary.receivedAt <= maxStoredAgeMillis
    }

    private static func isWithinTransientActionWindow(_ summary: LocalNotificationSummary, now: Int64) -> Bool {
        guard summary.receivedAt <= now else {
            return true
        }
        return now - summary.receivedAt <= maxTransientActionAgeMillis
    }

    private static func isTransientAppIdentifier(_ rawValue: String?) -> Bool {
        let value = rawValue.orEmpty.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return transientAppIdentifiers.contains(value)
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}
