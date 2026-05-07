import Foundation

enum EventKind: String, Codable, Sendable {
    case notification
}

struct NotificationPayload: Codable, Equatable, Sendable {
    let appPackage: String
    let appName: String
    let title: String
    let text: String
    let notificationKey: String
}

enum EventPayload: Codable, Equatable, Sendable {
    case notification(NotificationPayload)
}

struct EventMetadata: Codable, Equatable, Sendable {
    let route: String
    let sourceAppPackage: String?
}

struct InboundEvent: Codable, Equatable, Sendable {
    let eventId: String
    let kind: EventKind
    let sourceDeviceId: String
    let occurredAt: Int64
    let receivedAt: Int64
    let payload: EventPayload
    let metadata: EventMetadata
}

enum ActionKind: String, Codable, Sendable {
    case showNotification = "show_notification"
    case copyVerificationCode = "copy_verification_code"
    case openLink = "open_link"
    case copyText = "copy_text"
    case openFile = "open_file"
    case revealFile = "reveal_file"
    case copyFilePath = "copy_file_path"
    case recordHistory = "record_history"
}

enum ActionPriority: Int, Codable, Comparable, Sendable {
    case low = 0
    case medium = 50
    case high = 100

    static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum ActionPayload: Codable, Equatable, Sendable {
    case none
    case verificationCode(code: String, senderLabel: String?)
    case link(url: String)
    case text(value: String)
    case file(path: String, fileName: String, mimeType: String?)
    case notificationPreview(title: String, text: String)
    case historyRecord
}

struct ActionCandidate: Codable, Equatable, Identifiable, Sendable {
    let actionId: String
    let sourceEventId: String
    let kind: ActionKind
    let title: String
    let value: String?
    let priority: ActionPriority
    let payload: ActionPayload

    var id: String {
        actionId
    }
}

extension ActionCandidate {
    var verificationCode: String? {
        guard case let .verificationCode(code, _) = payload else {
            return nil
        }
        return code
    }

    var verificationSenderLabel: String? {
        guard case let .verificationCode(_, senderLabel) = payload else {
            return nil
        }
        return senderLabel
    }

    var linkURLString: String? {
        guard case let .link(url) = payload else {
            return nil
        }
        return url
    }

    var textValue: String? {
        guard case let .text(value) = payload else {
            return nil
        }
        return value
    }

    var fileValue: (path: String, fileName: String, mimeType: String?)? {
        guard case let .file(path, fileName, mimeType) = payload else {
            return nil
        }
        return (path, fileName, mimeType)
    }

    var isUserVisible: Bool {
        switch kind {
        case .copyVerificationCode, .openLink, .copyText, .openFile, .revealFile, .copyFilePath:
            return true
        case .showNotification, .recordHistory:
            return false
        }
    }
}

enum HistoryPolicy: String, Codable, Sendable {
    case record
    case skip
}

enum RouteSurface: String, Codable, Sendable {
    case systemNotification = "system_notification"
    case actionInbox = "action_inbox"
    case statusCard = "status_card"
    case history
    case discard
}

enum InterruptionLevel: String, Codable, Sendable {
    case none
    case passive
    case notify
    case urgent
}

enum PersistencePolicy: String, Codable, Sendable {
    case skip
    case transient
    case record
    case stateOnly = "state_only"
}

enum PrivacyLevel: String, Codable, Sendable {
    case standard
    case sensitive
}

struct StatusCardPolicy: Codable, Equatable, Sendable {
    let shouldUpdateCard: Bool
    let shouldNotifyOnTerminal: Bool

    static let quietUpdate = StatusCardPolicy(
        shouldUpdateCard: true,
        shouldNotifyOnTerminal: false
    )

    static let terminalUpdate = StatusCardPolicy(
        shouldUpdateCard: true,
        shouldNotifyOnTerminal: true
    )
}

struct RuleDecision: Codable, Equatable, Sendable {
    let shouldPresentSystemNotification: Bool
    let historyPolicy: HistoryPolicy
    let visibleActionIds: [String]
    let defaultActionId: String?
    let reasonCodes: [String]
    let primarySurface: RouteSurface
    let secondarySurfaces: [RouteSurface]
    let interruptionLevel: InterruptionLevel
    let persistencePolicy: PersistencePolicy
    let statusCardPolicy: StatusCardPolicy?
    let privacyLevel: PrivacyLevel

    init(
        shouldPresentSystemNotification: Bool,
        historyPolicy: HistoryPolicy,
        visibleActionIds: [String],
        defaultActionId: String?,
        reasonCodes: [String],
        primarySurface: RouteSurface? = nil,
        secondarySurfaces: [RouteSurface]? = nil,
        interruptionLevel: InterruptionLevel? = nil,
        persistencePolicy: PersistencePolicy? = nil,
        statusCardPolicy: StatusCardPolicy? = nil,
        privacyLevel: PrivacyLevel? = nil
    ) {
        self.shouldPresentSystemNotification = shouldPresentSystemNotification
        self.historyPolicy = historyPolicy
        self.visibleActionIds = visibleActionIds
        self.defaultActionId = defaultActionId
        self.reasonCodes = reasonCodes
        self.primarySurface = primarySurface ?? Self.derivedPrimarySurface(
            shouldPresentSystemNotification: shouldPresentSystemNotification,
            historyPolicy: historyPolicy,
            visibleActionIds: visibleActionIds
        )
        self.secondarySurfaces = secondarySurfaces ?? Self.derivedSecondarySurfaces(
            primarySurface: self.primarySurface,
            shouldPresentSystemNotification: shouldPresentSystemNotification,
            historyPolicy: historyPolicy,
            visibleActionIds: visibleActionIds
        )
        self.interruptionLevel = interruptionLevel ?? Self.derivedInterruptionLevel(
            shouldPresentSystemNotification: shouldPresentSystemNotification,
            visibleActionIds: visibleActionIds
        )
        self.persistencePolicy = persistencePolicy ?? Self.derivedPersistencePolicy(
            historyPolicy: historyPolicy,
            visibleActionIds: visibleActionIds
        )
        self.statusCardPolicy = statusCardPolicy
        self.privacyLevel = privacyLevel ?? Self.derivedPrivacyLevel(
            historyPolicy: historyPolicy,
            visibleActionIds: visibleActionIds
        )
    }

    static func legacyDefault(eventId: String, actionCandidates: [ActionCandidate]) -> RuleDecision {
        passthrough(eventId: eventId, actionCandidates: actionCandidates, reasonCode: "legacy_notification_summary")
    }

    static func passthrough(
        eventId: String,
        actionCandidates: [ActionCandidate],
        reasonCode: String = "mac_rules_disabled"
    ) -> RuleDecision {
        let visibleActionIds = actionCandidates
            .filter(\.isUserVisible)
            .map(\.actionId)
        let defaultActionId = actionCandidates
            .filter(\.isUserVisible)
            .sorted { lhs, rhs in lhs.priority > rhs.priority }
            .first?
            .actionId

        return RuleDecision(
            shouldPresentSystemNotification: false,
            historyPolicy: .record,
            visibleActionIds: visibleActionIds,
            defaultActionId: defaultActionId,
            reasonCodes: [reasonCode, "event:\(eventId)"]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case shouldPresentSystemNotification
        case historyPolicy
        case visibleActionIds
        case defaultActionId
        case reasonCodes
        case primarySurface
        case secondarySurfaces
        case interruptionLevel
        case persistencePolicy
        case statusCardPolicy
        case privacyLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedPrimarySurface = try container.decodeIfPresent(RouteSurface.self, forKey: .primarySurface)
        let decodedInterruptionLevel = try container.decodeIfPresent(InterruptionLevel.self, forKey: .interruptionLevel)
        let decodedPersistencePolicy = try container.decodeIfPresent(PersistencePolicy.self, forKey: .persistencePolicy)
        let decodedVisibleActionIds = try container.decodeIfPresent([String].self, forKey: .visibleActionIds) ?? []
        let decodedHistoryPolicy = try container.decodeIfPresent(HistoryPolicy.self, forKey: .historyPolicy)
        let decodedShouldPresent = try container.decodeIfPresent(Bool.self, forKey: .shouldPresentSystemNotification)

        let shouldPresentSystemNotification = decodedShouldPresent
            ?? Self.derivedShouldPresent(
                primarySurface: decodedPrimarySurface,
                interruptionLevel: decodedInterruptionLevel
            )
        let historyPolicy = decodedHistoryPolicy
            ?? Self.derivedHistoryPolicy(persistencePolicy: decodedPersistencePolicy)

        self.init(
            shouldPresentSystemNotification: shouldPresentSystemNotification,
            historyPolicy: historyPolicy,
            visibleActionIds: decodedVisibleActionIds,
            defaultActionId: try container.decodeIfPresent(String.self, forKey: .defaultActionId),
            reasonCodes: try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? [],
            primarySurface: decodedPrimarySurface,
            secondarySurfaces: try container.decodeIfPresent([RouteSurface].self, forKey: .secondarySurfaces),
            interruptionLevel: decodedInterruptionLevel,
            persistencePolicy: decodedPersistencePolicy,
            statusCardPolicy: try container.decodeIfPresent(StatusCardPolicy.self, forKey: .statusCardPolicy),
            privacyLevel: try container.decodeIfPresent(PrivacyLevel.self, forKey: .privacyLevel)
        )
    }

    private static func derivedPrimarySurface(
        shouldPresentSystemNotification: Bool,
        historyPolicy: HistoryPolicy,
        visibleActionIds: [String]
    ) -> RouteSurface {
        if shouldPresentSystemNotification {
            return .systemNotification
        }
        if !visibleActionIds.isEmpty {
            return .actionInbox
        }
        return historyPolicy == .record ? .history : .discard
    }

    private static func derivedSecondarySurfaces(
        primarySurface: RouteSurface,
        shouldPresentSystemNotification: Bool,
        historyPolicy: HistoryPolicy,
        visibleActionIds: [String]
    ) -> [RouteSurface] {
        var surfaces: [RouteSurface] = []
        if shouldPresentSystemNotification, primarySurface != .systemNotification {
            surfaces.append(.systemNotification)
        }
        if !visibleActionIds.isEmpty, primarySurface != .actionInbox {
            surfaces.append(.actionInbox)
        }
        if historyPolicy == .record, primarySurface != .history {
            surfaces.append(.history)
        }
        return surfaces
    }

    private static func derivedInterruptionLevel(
        shouldPresentSystemNotification: Bool,
        visibleActionIds: [String]
    ) -> InterruptionLevel {
        guard shouldPresentSystemNotification else {
            return visibleActionIds.isEmpty ? InterruptionLevel.none : .passive
        }
        return visibleActionIds.isEmpty ? .notify : .urgent
    }

    private static func derivedPersistencePolicy(
        historyPolicy: HistoryPolicy,
        visibleActionIds: [String]
    ) -> PersistencePolicy {
        switch historyPolicy {
        case .record:
            return .record
        case .skip:
            return visibleActionIds.isEmpty ? .skip : .transient
        }
    }

    private static func derivedPrivacyLevel(
        historyPolicy: HistoryPolicy,
        visibleActionIds: [String]
    ) -> PrivacyLevel {
        historyPolicy == .skip && !visibleActionIds.isEmpty ? .sensitive : .standard
    }

    private static func derivedShouldPresent(
        primarySurface: RouteSurface?,
        interruptionLevel: InterruptionLevel?
    ) -> Bool {
        switch interruptionLevel {
        case .some(.notify), .some(.urgent):
            return true
        case .some(InterruptionLevel.none), .some(.passive):
            return false
        case nil:
            return primarySurface == .systemNotification
        }
    }

    private static func derivedHistoryPolicy(
        persistencePolicy: PersistencePolicy?
    ) -> HistoryPolicy {
        persistencePolicy == .record ? .record : .skip
    }
}

enum ActionExecutionStatus: String, Codable, Sendable {
    case success
    case failed
}

struct ActionResult: Codable, Equatable, Sendable {
    let actionId: String
    let sourceEventId: String
    let status: ActionExecutionStatus
    let executedAt: Int64
    let message: String?
}
