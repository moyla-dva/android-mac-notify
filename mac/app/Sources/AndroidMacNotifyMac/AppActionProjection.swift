import Foundation

struct AppTransientActionSummaryProjection: Equatable {
    let summariesByEventId: [String: LocalNotificationSummary]
    let transientNotifications: [LocalNotificationSummary]
}

enum AppActionProjection {
    static func actionInboxNotifications(
        lastNotificationSummary: LocalNotificationSummary?,
        transientNotifications: [LocalNotificationSummary],
        recentNotifications: [LocalNotificationSummary],
        actionResultsById: [String: ActionResult]
    ) -> [LocalNotificationSummary] {
        let handledIds = handledEventIds(in: actionResultsById)
        return routedSummaries(
            lastNotificationSummary: lastNotificationSummary,
            transientNotifications: transientNotifications,
            recentNotifications: recentNotifications
        ) {
            $0.routesToActionInbox &&
                !handledIds.contains($0.eventId) &&
                !$0.isSharedFileReceipt &&
                !$0.visibleActionCandidates.isEmpty
        }
    }

    static func recentActivityNotifications(
        lastNotificationSummary: LocalNotificationSummary?,
        transientNotifications: [LocalNotificationSummary],
        recentNotifications: [LocalNotificationSummary],
        actionResultsById: [String: ActionResult],
        now: Int64
    ) -> [LocalNotificationSummary] {
        let pendingEventIds = Set(
            actionInboxNotifications(
                lastNotificationSummary: lastNotificationSummary,
                transientNotifications: transientNotifications,
                recentNotifications: recentNotifications,
                actionResultsById: actionResultsById
            ).map(\.eventId)
        )

        return routedSummaries(
            lastNotificationSummary: lastNotificationSummary,
            transientNotifications: transientNotifications,
            recentNotifications: recentNotifications
        ) { summary in
            guard !pendingEventIds.contains(summary.eventId) else {
                return false
            }
            guard !summary.isSharedFileReceipt else {
                return false
            }
            if summary.routesToHistory {
                return true
            }
            return summary.ruleDecision.persistencePolicy == .transient
                && isEventHandled(summary, actionResultsById: actionResultsById)
                && NotificationHistoryPolicy.shouldKeepTransientActionSummary(summary, now: now)
        }
    }

    static func visibleActionCandidates(
        for summary: LocalNotificationSummary,
        hidingCompletedActions: Bool,
        actionResultsById: [String: ActionResult]
    ) -> [ActionCandidate] {
        if hidingCompletedActions, isEventHandled(summary, actionResultsById: actionResultsById) {
            return []
        }
        guard hidingCompletedActions else {
            return summary.visibleActionCandidates
        }
        return summary.visibleActionCandidates(
            handledEventIds: handledEventIds(in: actionResultsById),
            completedActionIds: completedActionIds(in: actionResultsById)
        )
    }

    static func actionResult(
        for action: ActionCandidate,
        actionResultsById: [String: ActionResult]
    ) -> ActionResult? {
        actionResultsById[action.actionId]
    }

    static func failedActionResults(
        for summary: LocalNotificationSummary,
        actionResultsById: [String: ActionResult]
    ) -> [ActionResult] {
        guard !isEventHandled(summary, actionResultsById: actionResultsById) else {
            return []
        }
        return summary.visibleActionCandidates.compactMap { action -> ActionResult? in
            guard let result = actionResult(for: action, actionResultsById: actionResultsById),
                  result.status == .failed
            else {
                return nil
            }
            return result
        }
    }

    static func isActionCompleted(
        _ action: ActionCandidate,
        actionResultsById: [String: ActionResult]
    ) -> Bool {
        actionResult(for: action, actionResultsById: actionResultsById)?.status == .success
    }

    static func isEventHandled(
        _ summary: LocalNotificationSummary,
        actionResultsById: [String: ActionResult]
    ) -> Bool {
        handledEventIds(in: actionResultsById).contains(summary.eventId)
    }

    static func areVisibleActionsCompleted(
        for summary: LocalNotificationSummary,
        actionResultsById: [String: ActionResult]
    ) -> Bool {
        let actions = summary.visibleActionCandidates
        guard !actions.isEmpty else {
            return false
        }
        return actions.allSatisfy {
            isActionCompleted($0, actionResultsById: actionResultsById)
        }
    }

    static func pendingVisibleActionCount(
        for summary: LocalNotificationSummary,
        actionResultsById: [String: ActionResult]
    ) -> Int {
        guard !isEventHandled(summary, actionResultsById: actionResultsById) else {
            return 0
        }
        return summary.visibleActionCandidates.filter {
            !isActionCompleted($0, actionResultsById: actionResultsById)
        }.count
    }

    static func shouldPublishActionPrompt(
        for summary: LocalNotificationSummary,
        actionResultsById: [String: ActionResult]
    ) -> Bool {
        if summary.isSharedFileReceipt {
            return true
        }
        return summary.hasPendingVisibleActions(
            handledEventIds: handledEventIds(in: actionResultsById)
        )
    }

    static func transientActionSummaryProjection(
        upserting summary: LocalNotificationSummary,
        into currentSummariesByEventId: [String: LocalNotificationSummary],
        now: Int64
    ) -> AppTransientActionSummaryProjection {
        var summariesByEventId = currentSummariesByEventId
        summariesByEventId[summary.eventId] = summary

        let trimmed = NotificationHistoryPolicy.transientActionSummaries(
            from: Array(summariesByEventId.values),
            now: now
        )

        return AppTransientActionSummaryProjection(
            summariesByEventId: Dictionary(uniqueKeysWithValues: trimmed.map { ($0.eventId, $0) }),
            transientNotifications: trimmed
        )
    }

    static func handledEventIds(in actionResultsById: [String: ActionResult]) -> Set<String> {
        Set(actionResultsById.values.compactMap { result in
            result.status == .success ? result.sourceEventId : nil
        })
    }

    static func completedActionIds(in actionResultsById: [String: ActionResult]) -> Set<String> {
        Set(actionResultsById.values.compactMap { result in
            result.status == .success ? result.actionId : nil
        })
    }

    static func routedSummaries(
        lastNotificationSummary: LocalNotificationSummary?,
        transientNotifications: [LocalNotificationSummary],
        recentNotifications: [LocalNotificationSummary],
        where shouldInclude: (LocalNotificationSummary) -> Bool
    ) -> [LocalNotificationSummary] {
        let candidates = [lastNotificationSummary].compactMap { $0 }
            + transientNotifications
            + recentNotifications
        var seenEventIds: Set<String> = []
        var summaries: [LocalNotificationSummary] = []

        for summary in candidates.sorted(by: { $0.receivedAt > $1.receivedAt }) {
            guard shouldInclude(summary), !seenEventIds.contains(summary.eventId) else {
                continue
            }
            seenEventIds.insert(summary.eventId)
            summaries.append(summary)
        }

        return summaries
    }
}
