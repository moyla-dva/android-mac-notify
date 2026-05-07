import AppKit
import Foundation

extension AppState {
    func copyVerificationCode(from summary: LocalNotificationSummary) {
        if let action = summary.actionCandidates.first(where: { $0.kind == .copyVerificationCode }) {
            execute(action: action, from: summary)
            return
        }

        guard let verificationCode = summary.verificationCode else {
            actionFeedbackMessage = "当前通知没有可复制的验证码"
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(verificationCode, forType: .string)

        if let sender = summary.verificationSenderLabel {
            actionFeedbackMessage = "已复制 \(sender) 验证码 \(verificationCode)"
        } else {
            actionFeedbackMessage = "已复制验证码 \(verificationCode)"
        }
        writeDiagnosticState()
    }

    func executeNotificationAction(eventId: String, actionIdentifier: String) {
        let summary = notificationSummary(for: eventId)
        switch AppNotificationActionResolver.resolve(
            eventId: eventId,
            actionIdentifier: actionIdentifier,
            summary: summary
        ) {
        case let .failureMessage(message):
            actionFeedbackMessage = message
            writeDiagnosticState()
            return
        case let .resolved(action, summary):
            execute(action: action, from: summary)
        }
    }

    func execute(action: ActionCandidate, from summary: LocalNotificationSummary) {
        guard action.sourceEventId == summary.eventId else {
            let result = ActionResult(
                actionId: action.actionId,
                sourceEventId: action.sourceEventId,
                status: .failed,
                executedAt: Int64(Date().timeIntervalSince1970 * 1000),
                message: "动作和通知不匹配"
            )
            record(actionResult: result)
            actionFeedbackMessage = result.message
            writeDiagnosticState()
            return
        }

        let result = ActionExecutor.execute(action)
        record(actionResult: result)
        actionFeedbackMessage = result.message
        writeDiagnosticState()
    }

    func visibleActionCandidates(
        for summary: LocalNotificationSummary,
        hidingCompletedActions: Bool
    ) -> [ActionCandidate] {
        AppActionProjection.visibleActionCandidates(
            for: summary,
            hidingCompletedActions: hidingCompletedActions,
            actionResultsById: actionResultsById
        )
    }

    func actionResult(for action: ActionCandidate) -> ActionResult? {
        AppActionProjection.actionResult(for: action, actionResultsById: actionResultsById)
    }

    func failedActionResults(for summary: LocalNotificationSummary) -> [ActionResult] {
        AppActionProjection.failedActionResults(for: summary, actionResultsById: actionResultsById)
    }

    func isActionCompleted(_ action: ActionCandidate) -> Bool {
        AppActionProjection.isActionCompleted(action, actionResultsById: actionResultsById)
    }

    func isEventHandled(_ summary: LocalNotificationSummary) -> Bool {
        AppActionProjection.isEventHandled(summary, actionResultsById: actionResultsById)
    }

    func areVisibleActionsCompleted(for summary: LocalNotificationSummary) -> Bool {
        AppActionProjection.areVisibleActionsCompleted(for: summary, actionResultsById: actionResultsById)
    }

    func pendingVisibleActionCount(for summary: LocalNotificationSummary) -> Int {
        AppActionProjection.pendingVisibleActionCount(for: summary, actionResultsById: actionResultsById)
    }

    func publishActionPromptIfNeeded(for summary: LocalNotificationSummary) {
        guard AppActionProjection.shouldPublishActionPrompt(
            for: summary,
            actionResultsById: actionResultsById
        ) else {
            return
        }
        actionPromptSubject.send(summary)
    }

    func loadPersistedActionResults() async {
        switch await actionResultPersistenceController.loadResultsById() {
        case let .loaded(resultsById):
            actionResultsById = resultsById
            writeDiagnosticState()
        case let .failed(message):
            lastError = message
            writeDiagnosticState()
        }
    }

    func persistActionResults() {
        let resultsById = actionResultsById
        Task { [weak self, actionResultPersistenceController] in
            if let message = await actionResultPersistenceController.save(resultsById) {
                await MainActor.run {
                    self?.lastError = message
                    self?.writeDiagnosticState()
                }
            }
        }
    }

    func clearPersistedActionResults() async {
        if let message = await actionResultPersistenceController.clear() {
            lastError = message
        }
    }

    func notificationSummary(for eventId: String) -> LocalNotificationSummary? {
        if lastNotificationSummary?.eventId == eventId {
            return lastNotificationSummary
        }
        if let summary = transientActionSummaries[eventId] {
            return summary
        }
        return recentNotifications.first { $0.eventId == eventId }
    }

    private func record(actionResult: ActionResult) {
        var nextResults = actionResultsById
        nextResults[actionResult.actionId] = actionResult
        actionResultsById = nextResults
        lastActionResult = actionResult
        persistActionResults()
        if actionResult.status == .success {
            actionCompletedSubject.send(actionResult)
        }
    }
}
