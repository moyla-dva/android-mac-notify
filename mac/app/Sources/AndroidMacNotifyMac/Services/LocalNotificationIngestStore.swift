import Foundation

struct LocalNotificationIngestResult: Sendable {
    let response: NotificationAcceptedResponse
    let acceptedSummary: LocalNotificationSummary?
}

struct LocalNotificationIngestStore: Sendable {
    private static let acceptedEventIDRetentionMillis: Int64 = 24 * 60 * 60 * 1_000
    private static let maxAcceptedEventIDCount = 1_000

    private var acceptedEventIDs: Set<String> = []
    private var acceptedEventTimestampsById: [String: Int64] = [:]
    private var recentNotifications: [LocalNotificationSummary] = []

    var storedSummaries: [LocalNotificationSummary] {
        recentNotifications
    }

    mutating func replacePersistedSummaries(_ summaries: [LocalNotificationSummary], now: Int64) -> Bool {
        let storedSummaries = NotificationHistoryPolicy.storedSummaries(from: summaries, now: now)
        recentNotifications = storedSummaries
        acceptedEventIDs = Set(recentNotifications.map(\.eventId))
        acceptedEventTimestampsById = Dictionary(
            uniqueKeysWithValues: recentNotifications.map { ($0.eventId, $0.receivedAt) }
        )
        return storedSummaries != summaries
    }

    mutating func removeAll() {
        acceptedEventIDs.removeAll()
        acceptedEventTimestampsById.removeAll()
        recentNotifications.removeAll()
    }

    mutating func clear(eventId: String) {
        recentNotifications.removeAll { $0.eventId == eventId }
    }

    mutating func ingest(
        payload: NotificationEventPayload,
        receivedAt: Int64
    ) -> LocalNotificationIngestResult {
        let isDeduplicated = acceptedEventIDs.contains(payload.eventId)
        if isDeduplicated {
            return LocalNotificationIngestResult(
                response: NotificationAcceptedResponse(
                    accepted: true,
                    eventId: payload.eventId,
                    deduplicated: true,
                    receivedAt: receivedAt
                ),
                acceptedSummary: nil
            )
        }

        acceptedEventIDs.insert(payload.eventId)
        acceptedEventTimestampsById[payload.eventId] = receivedAt

        let summary = makeSummary(payload: payload, receivedAt: receivedAt)
        if NotificationHistoryPolicy.shouldPersist(summary, now: receivedAt) {
            recentNotifications.removeAll { $0.eventId == summary.eventId }
            recentNotifications.insert(summary, at: 0)
        }
        recentNotifications = NotificationHistoryPolicy.storedSummaries(from: recentNotifications, now: receivedAt)
        pruneAcceptedEventIDs(now: receivedAt)

        return LocalNotificationIngestResult(
            response: NotificationAcceptedResponse(
                accepted: true,
                eventId: payload.eventId,
                deduplicated: false,
                receivedAt: receivedAt
            ),
            acceptedSummary: summary
        )
    }

    private func makeSummary(
        payload: NotificationEventPayload,
        receivedAt: Int64
    ) -> LocalNotificationSummary {
        let inboundEvent = EventIngest.notificationEvent(from: payload, receivedAt: receivedAt)
        let actionCandidates = ActionClassifier.candidates(for: inboundEvent)
        let ruleDecision = RuleDecision.passthrough(
            eventId: inboundEvent.eventId,
            actionCandidates: actionCandidates
        )

        let verificationContext = actionCandidates.first(where: { $0.kind == .copyVerificationCode }).flatMap { action -> VerificationCodeContext? in
            guard let code = action.verificationCode else {
                return nil
            }
            return VerificationCodeContext(code: code, senderLabel: action.verificationSenderLabel)
        }

        return LocalNotificationSummary(
            eventId: payload.eventId,
            deviceId: payload.deviceId,
            appPackage: payload.appPackage,
            appName: payload.appName,
            title: payload.title,
            text: payload.text,
            receivedAt: receivedAt,
            verificationContext: verificationContext,
            actionCandidates: actionCandidates,
            ruleDecision: ruleDecision
        )
    }

    private mutating func pruneAcceptedEventIDs(now: Int64) {
        let retainedHistoryIds = Set(recentNotifications.map(\.eventId))
        let cutoff = now - Self.acceptedEventIDRetentionMillis
        acceptedEventTimestampsById = acceptedEventTimestampsById.filter { eventId, timestamp in
            retainedHistoryIds.contains(eventId) || timestamp >= cutoff
        }

        if acceptedEventTimestampsById.count > Self.maxAcceptedEventIDCount {
            let kept = acceptedEventTimestampsById
                .sorted { $0.value > $1.value }
                .prefix(Self.maxAcceptedEventIDCount)
            acceptedEventTimestampsById = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }

        acceptedEventIDs = Set(acceptedEventTimestampsById.keys).union(retainedHistoryIds)
    }
}
