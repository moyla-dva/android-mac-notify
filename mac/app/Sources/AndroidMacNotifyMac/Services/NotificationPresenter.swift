import Foundation
import UserNotifications

// Reserved for explicit high-priority system notifications. Normal Android events currently
// surface through the menu bar and action inbox instead of macOS Notification Center.
enum NotificationPresenter {
    @MainActor
    private static let responseDelegate = NotificationResponseDelegate()
    private static let eventIdUserInfoKey = "eventId"
    private static let defaultActionKindUserInfoKey = "defaultActionKind"

    private static var isBundleBackedApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    @MainActor
    static func configure(actionHandler: @escaping @Sendable (_ eventId: String, _ actionIdentifier: String) -> Void) {
        guard isBundleBackedApp else {
            return
        }

        responseDelegate.actionHandler = actionHandler
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = responseDelegate
        notificationCenter.setNotificationCategories(notificationCategories())
    }

    static func requestAuthorization() async {
        guard isBundleBackedApp else {
            return
        }

        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert])
        } catch {
            // Keep MVP lightweight: failure is non-fatal and can be surfaced later in diagnostics.
        }
    }

    static func shouldPresent(summary: LocalNotificationSummary) -> Bool {
        let decision = summary.ruleDecision
        guard decision.interruptionLevel == .notify || decision.interruptionLevel == .urgent else {
            return false
        }

        return decision.primarySurface == .systemNotification
            || decision.secondarySurfaces.contains(.systemNotification)
    }

    static func present(summary: LocalNotificationSummary) async {
        guard isBundleBackedApp else {
            return
        }
        guard shouldPresent(summary: summary) else {
            return
        }

        let plan = contentPlan(for: summary)
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.subtitle = plan.subtitle
        content.body = plan.body
        content.threadIdentifier = "amn.\(summary.ruleDecision.primarySurface.rawValue)"
        if summary.ruleDecision.interruptionLevel == .urgent {
            content.sound = .default
        }
        var userInfo: [String: Any] = [
            eventIdUserInfoKey: summary.eventId,
            "primarySurface": summary.ruleDecision.primarySurface.rawValue,
            "interruptionLevel": summary.ruleDecision.interruptionLevel.rawValue,
        ]
        if let defaultActionKind = defaultActionKind(for: summary) {
            userInfo[defaultActionKindUserInfoKey] = defaultActionKind.rawValue
        }
        content.userInfo = userInfo
        if let categoryIdentifier = categoryIdentifier(for: summary.visibleActionCandidates) {
            content.categoryIdentifier = categoryIdentifier
        }

        let request = UNNotificationRequest(
            identifier: summary.eventId,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // MVP keeps notification delivery best-effort.
        }
    }

    static func presentActionResult(_ result: ActionResult) async {
        guard isBundleBackedApp, let message = result.message, !message.isEmpty else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "动作失败"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "action-result-\(result.actionId)-\(result.executedAt)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Feedback notification is best-effort.
        }
    }

    private static func contentPlan(for summary: LocalNotificationSummary) -> NotificationContentPlan {
        if summary.ruleDecision.primarySurface == .statusCard,
           let card = StatusCardClassifier.cardState(from: summary) {
            return NotificationContentPlan(
                title: card.title,
                subtitle: card.appName,
                body: card.detail
            )
        }

        if let verificationCode = summary.verificationCode {
            let title: String
            if let senderLabel = summary.verificationSenderLabel {
                title = "\(senderLabel) 验证码 \(verificationCode)"
            } else {
                title = "验证码 \(verificationCode)"
            }

            return NotificationContentPlan(
                title: title,
                subtitle: summary.appName,
                body: [summary.title, summary.text]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
            )
        }

        let title = summary.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = summary.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if defaultActionKind(for: summary) == .openLink, title.isEmpty {
            return NotificationContentPlan(
                title: "收到链接",
                subtitle: summary.appName,
                body: body
            )
        }

        if defaultActionKind(for: summary) == .copyText, title.isEmpty {
            return NotificationContentPlan(
                title: "收到文本",
                subtitle: summary.appName,
                body: body
            )
        }

        if defaultActionKind(for: summary) == .openFile {
            return NotificationContentPlan(
                title: "收到文件",
                subtitle: summary.appName,
                body: [title, body]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")
            )
        }

        return NotificationContentPlan(
            title: title.isEmpty ? summary.appName : title,
            subtitle: summary.appName,
            body: body
        )
    }

    private static func defaultActionKind(for summary: LocalNotificationSummary) -> ActionKind? {
        if let defaultActionId = summary.ruleDecision.defaultActionId,
           let defaultAction = summary.visibleActionCandidates.first(where: { $0.actionId == defaultActionId }) {
            return defaultAction.kind
        }

        return summary.visibleActionCandidates.first?.kind
    }

    private static func notificationCategories() -> Set<UNNotificationCategory> {
        let supportedActionKinds: [ActionKind] = [
            .copyVerificationCode,
            .openLink,
            .copyText,
            .openFile,
            .revealFile,
            .copyFilePath,
        ]
        var categories: Set<UNNotificationCategory> = []

        for mask in 1 ..< (1 << supportedActionKinds.count) {
            let kinds = supportedActionKinds.enumerated().compactMap { index, kind in
                (mask & (1 << index)) == 0 ? nil : kind
            }
            categories.insert(
                UNNotificationCategory(
                    identifier: categoryIdentifier(for: kinds),
                    actions: kinds.map(notificationAction(for:)),
                    intentIdentifiers: [],
                    options: []
                )
            )
        }

        return categories
    }

    private static func categoryIdentifier(for actions: [ActionCandidate]) -> String? {
        let visibleKinds = orderedUniqueActionKinds(from: actions.map(\.kind))
        guard !visibleKinds.isEmpty else {
            return nil
        }
        return categoryIdentifier(for: visibleKinds)
    }

    private static func categoryIdentifier(for kinds: [ActionKind]) -> String {
        "amn.actions.\(kinds.map(\.rawValue).joined(separator: "."))"
    }

    private static func orderedUniqueActionKinds(from kinds: [ActionKind]) -> [ActionKind] {
        let supportedOrder: [ActionKind] = [
            .copyVerificationCode,
            .openLink,
            .copyText,
            .openFile,
            .revealFile,
            .copyFilePath,
        ]
        return supportedOrder.filter { kind in
            kinds.contains(kind)
        }
    }

    private static func notificationAction(for kind: ActionKind) -> UNNotificationAction {
        UNNotificationAction(
            identifier: kind.rawValue,
            title: notificationActionTitle(for: kind),
            options: []
        )
    }

    private static func notificationActionTitle(for kind: ActionKind) -> String {
        switch kind {
        case .copyVerificationCode:
            return "复制验证码"
        case .openLink:
            return "打开链接"
        case .copyText:
            return "复制文本"
        case .openFile:
            return "打开文件"
        case .revealFile:
            return "在 Finder 中显示"
        case .copyFilePath:
            return "复制路径"
        case .showNotification:
            return "显示通知"
        case .recordHistory:
            return "记录历史"
        }
    }
}

private struct NotificationContentPlan {
    let title: String
    let subtitle: String
    let body: String
}

private final class NotificationResponseDelegate: NSObject, UNUserNotificationCenterDelegate {
    var actionHandler: (@Sendable (_ eventId: String, _ actionIdentifier: String) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        var options: UNNotificationPresentationOptions = [.banner, .list]
        if notification.request.content.sound != nil {
            options.insert(.sound)
        }
        completionHandler(options)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer {
            completionHandler()
        }

        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              let eventId = response.notification.request.content.userInfo["eventId"] as? String
        else {
            return
        }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            guard let defaultActionKind = response.notification.request.content.userInfo["defaultActionKind"] as? String else {
                return
            }
            actionHandler?(eventId, defaultActionKind)
            return
        }

        actionHandler?(eventId, response.actionIdentifier)
    }
}
