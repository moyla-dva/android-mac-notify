import Foundation

struct DeviceIdentity: Codable, Equatable, Sendable {
    let deviceId: String
    let platform: String
    let displayName: String
}

struct PairRegisterRequest: Codable, Sendable {
    let pairingToken: String
    let device: DeviceIdentity
}

struct PairRegisterResponse: Codable, Sendable {
    let deviceToken: String
    let macDeviceId: String
    let macDisplayName: String
    let serverTime: Int64
}

enum PairApprovalStatus: String, Codable, Equatable, Sendable {
    case pending
    case approved
    case rejected
    case expired
}

struct PairApprovalRequestPayload: Codable, Sendable {
    let device: DeviceIdentity
}

struct PairingApprovalRequest: Codable, Equatable, Sendable {
    let requestId: String
    let device: DeviceIdentity
    let requestedAt: Int64
    let expiresAt: Int64
    var status: PairApprovalStatus
}

struct PairApprovalStartResponse: Codable, Sendable {
    let requestId: String
    let status: PairApprovalStatus
    let macDeviceId: String
    let macDisplayName: String
    let expiresAt: Int64
    let serverTime: Int64
    let pollAfterMillis: Int
}

struct PairApprovalStatusResponse: Codable, Sendable {
    let requestId: String
    let status: PairApprovalStatus
    let macDeviceId: String
    let macDisplayName: String
    let serverTime: Int64
    let message: String?
    let registration: PairRegisterResponse?
}

struct NotificationEventPayload: Codable, Sendable {
    let eventId: String
    let deviceId: String
    let appPackage: String
    let appName: String
    let title: String
    let text: String
    let postedAt: Int64
    let notificationKey: String
}

struct NotificationAcceptedResponse: Codable, Sendable {
    let accepted: Bool
    let eventId: String
    let deduplicated: Bool
    let receivedAt: Int64
}

struct HeartbeatRequest: Codable, Sendable {
    let deviceId: String
    let sentAt: Int64
    let networkType: String
}

struct HeartbeatResponse: Codable, Sendable {
    let ok: Bool
    let serverTime: Int64
    let sessionState: String
}

enum RelayState: String, Codable, Equatable, Sendable {
    case active
    case paused
}

struct RelayStateRequest: Codable, Sendable {
    let deviceId: String
    let relayState: RelayState
    let sentAt: Int64
}

struct RelayStateResponse: Codable, Sendable {
    let ok: Bool
    let serverTime: Int64
    let sessionState: String
}

struct SessionForgetRequest: Codable, Sendable {
    let deviceId: String
    let sentAt: Int64
}

struct SessionForgetResponse: Codable, Sendable {
    let ok: Bool
    let serverTime: Int64
    let sessionState: String
}

struct SessionStatusResponse: Codable, Sendable {
    let deviceId: String
    let sessionState: String
    let lastSeenAt: Int64
    let macDeviceId: String
    let macDisplayName: String
}

struct DiscoveryResponse: Codable, Sendable {
    let protocolVersion: Int
    let serviceType: String
    let macDeviceId: String
    let macDisplayName: String
    let port: Int
    let serverTime: Int64
}

struct ShareTextRequest: Codable, Sendable {
    let deviceId: String
    let shareId: String
    let text: String
    let sharedAt: Int64
}

struct ShareTextAcceptedResponse: Codable, Sendable {
    let accepted: Bool
    let shareId: String
}

struct ShareFileAcceptedResponse: Codable, Sendable {
    let accepted: Bool
    let shareId: String
    let fileName: String
    let savedPath: String
    let size: Int64
}

struct SharedFileReceipt: Codable, Equatable, Sendable {
    let shareId: String
    let batchId: String?
    let batchIndex: Int?
    let batchTotal: Int?
    let deviceId: String
    let originalFileName: String?
    let fileName: String
    let savedPath: String
    let size: Int64
    let receivedAt: Int64

    init(
        shareId: String,
        batchId: String? = nil,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        deviceId: String,
        originalFileName: String? = nil,
        fileName: String,
        savedPath: String,
        size: Int64,
        receivedAt: Int64
    ) {
        self.shareId = shareId
        self.batchId = batchId
        self.batchIndex = batchIndex
        self.batchTotal = batchTotal
        self.deviceId = deviceId
        self.originalFileName = originalFileName
        self.fileName = fileName
        self.savedPath = savedPath
        self.size = size
        self.receivedAt = receivedAt
    }
}

struct ErrorEnvelope: Codable, Sendable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable, Sendable {
    let code: String
    let message: String
    let retryable: Bool?
}

struct VerificationCodeContext: Codable, Equatable, Sendable {
    let code: String
    let senderLabel: String?
}

struct LocalNotificationSummary: Codable, Equatable, Sendable {
    let eventId: String
    let deviceId: String
    let appPackage: String?
    let appName: String
    let title: String
    let text: String
    let receivedAt: Int64
    let verificationContext: VerificationCodeContext?
    let actionCandidates: [ActionCandidate]
    let ruleDecision: RuleDecision

    init(
        eventId: String,
        deviceId: String,
        appPackage: String? = nil,
        appName: String,
        title: String,
        text: String,
        receivedAt: Int64,
        verificationContext: VerificationCodeContext?,
        actionCandidates: [ActionCandidate] = [],
        ruleDecision: RuleDecision? = nil
    ) {
        self.eventId = eventId
        self.deviceId = deviceId
        self.appPackage = appPackage
        self.appName = appName
        self.title = title
        self.text = text
        self.receivedAt = receivedAt
        self.verificationContext = verificationContext
        self.actionCandidates = actionCandidates
        self.ruleDecision = ruleDecision ?? .legacyDefault(
            eventId: eventId,
            actionCandidates: actionCandidates
        )
    }

    private enum CodingKeys: String, CodingKey {
        case eventId
        case deviceId
        case appPackage
        case appName
        case title
        case text
        case receivedAt
        case verificationContext
        case actionCandidates
        case ruleDecision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(String.self, forKey: .eventId)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        appPackage = try container.decodeIfPresent(String.self, forKey: .appPackage)
        appName = try container.decode(String.self, forKey: .appName)
        title = try container.decode(String.self, forKey: .title)
        text = try container.decode(String.self, forKey: .text)
        receivedAt = try container.decode(Int64.self, forKey: .receivedAt)
        verificationContext = try container.decodeIfPresent(VerificationCodeContext.self, forKey: .verificationContext)
        actionCandidates = try container.decodeIfPresent([ActionCandidate].self, forKey: .actionCandidates) ?? []
        ruleDecision = try container.decodeIfPresent(RuleDecision.self, forKey: .ruleDecision)
            ?? .legacyDefault(eventId: eventId, actionCandidates: actionCandidates)
    }
}

extension LocalNotificationSummary {
    var verificationCode: String? {
        actionCandidates.first(where: { $0.kind == .copyVerificationCode })?.verificationCode
            ?? verificationContext?.code
    }

    var verificationSenderLabel: String? {
        actionCandidates.first(where: { $0.kind == .copyVerificationCode })?.verificationSenderLabel
            ?? verificationContext?.senderLabel
    }

    var visibleActionCandidates: [ActionCandidate] {
        let candidates = effectiveActionCandidates
        let visibleCandidates: [ActionCandidate]
        if !ruleDecision.visibleActionIds.isEmpty {
            visibleCandidates = ruleDecision.visibleActionIds.compactMap { actionId in
                candidates.first { $0.actionId == actionId }
            }
        } else if ruleDecision.primarySurface == .systemNotification
            || ruleDecision.secondarySurfaces.contains(.actionInbox) {
            visibleCandidates = candidates.filter(\.isUserVisible)
        } else {
            visibleCandidates = []
        }

        return visibleCandidates.filter { NotificationHistoryPolicy.shouldExpose(action: $0, for: self) }
    }

    var shouldPresentSystemNotification: Bool {
        ruleDecision.shouldPresentSystemNotification
    }

    var routesToActionInbox: Bool {
        (ruleDecision.primarySurface == .actionInbox || ruleDecision.secondarySurfaces.contains(.actionInbox))
            && !visibleActionCandidates.isEmpty
    }

    var routesToHistory: Bool {
        ruleDecision.persistencePolicy == .record
    }

    func visibleActionCandidates(excludingCompletedActionIds completedActionIds: Set<String>) -> [ActionCandidate] {
        visibleActionCandidates.filter { !completedActionIds.contains($0.actionId) }
    }

    func hasPendingVisibleActions(completedActionIds: Set<String>) -> Bool {
        !visibleActionCandidates(excludingCompletedActionIds: completedActionIds).isEmpty
    }

    func hasPendingVisibleActions(handledEventIds: Set<String>) -> Bool {
        !handledEventIds.contains(eventId) && !visibleActionCandidates.isEmpty
    }

    func visibleActionCandidates(
        handledEventIds: Set<String>,
        completedActionIds: Set<String>
    ) -> [ActionCandidate] {
        guard !handledEventIds.contains(eventId) else {
            return []
        }
        return visibleActionCandidates(excludingCompletedActionIds: completedActionIds)
    }

    func replacing(ruleDecision: RuleDecision) -> LocalNotificationSummary {
        LocalNotificationSummary(
            eventId: eventId,
            deviceId: deviceId,
            appPackage: appPackage,
            appName: appName,
            title: title,
            text: text,
            receivedAt: receivedAt,
            verificationContext: verificationContext,
            actionCandidates: actionCandidates,
            ruleDecision: ruleDecision
        )
    }

    private var effectiveActionCandidates: [ActionCandidate] {
        if !actionCandidates.isEmpty {
            return actionCandidates
        }

        guard let verificationContext else {
            return []
        }

        return [
            ActionCandidate(
                actionId: "act_\(eventId)_copy-verification-code",
                sourceEventId: eventId,
                kind: .copyVerificationCode,
                title: "复制验证码",
                value: verificationContext.code,
                priority: .high,
                payload: .verificationCode(
                    code: verificationContext.code,
                    senderLabel: verificationContext.senderLabel
                )
            ),
        ]
    }
}
