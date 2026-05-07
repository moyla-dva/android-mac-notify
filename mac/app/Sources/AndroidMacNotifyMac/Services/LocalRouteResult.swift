import Foundation

struct LocalRouteFinalization: Sendable {
    let shouldPersist: Bool
    let shouldEmitPairingTokenUpdate: Bool
    let events: [LocalServerEvent]

    init(
        shouldPersist: Bool,
        shouldEmitPairingTokenUpdate: Bool = false,
        events: [LocalServerEvent] = []
    ) {
        self.shouldPersist = shouldPersist
        self.shouldEmitPairingTokenUpdate = shouldEmitPairingTokenUpdate
        self.events = events
    }
}

protocol LocalFinalizableRouteResult: Sendable {
    var finalization: LocalRouteFinalization { get }
}

protocol LocalHTTPRouteResult: LocalFinalizableRouteResult {
    var response: HTTPResponse { get }
}

protocol LocalSingleEventRouteResult: LocalFinalizableRouteResult {
    var shouldPersist: Bool { get }
    var event: LocalServerEvent? { get }
}

extension LocalSingleEventRouteResult {
    var finalization: LocalRouteFinalization {
        LocalRouteFinalization(
            shouldPersist: shouldPersist,
            events: event.map { [$0] } ?? []
        )
    }
}

extension LocalSessionRouteResult: LocalSingleEventRouteResult {}
extension LocalNotificationRouteResult: LocalSingleEventRouteResult {}
extension LocalShareRouteResult: LocalSingleEventRouteResult {}
extension LocalSessionRouteResult: LocalHTTPRouteResult {}
extension LocalNotificationRouteResult: LocalHTTPRouteResult {}
extension LocalShareRouteResult: LocalHTTPRouteResult {}

extension LocalPairingRouteResult: LocalHTTPRouteResult {
    var finalization: LocalRouteFinalization {
        LocalRouteFinalization(
            shouldPersist: shouldPersist,
            shouldEmitPairingTokenUpdate: didRotatePairingToken,
            events: events
        )
    }
}

extension LocalPairingActionResult: LocalFinalizableRouteResult {
    var finalization: LocalRouteFinalization {
        LocalRouteFinalization(
            shouldPersist: shouldPersist,
            events: events
        )
    }
}
