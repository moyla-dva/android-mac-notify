import Foundation

struct LocalServerRouteHandlers: Sendable {
    let routeDispatcher: LocalHTTPRouteDispatcher
    let discovery: LocalDiscoveryHandler
    let pairing: LocalPairingHandler
    let notification: LocalNotificationHandler
    let session: LocalSessionHandler
    let share: LocalShareHandler

    init(
        routeDispatcher: LocalHTTPRouteDispatcher = LocalHTTPRouteDispatcher(),
        discovery: LocalDiscoveryHandler,
        pairing: LocalPairingHandler,
        notification: LocalNotificationHandler = LocalNotificationHandler(),
        session: LocalSessionHandler = LocalSessionHandler(),
        share: LocalShareHandler = LocalShareHandler()
    ) {
        self.routeDispatcher = routeDispatcher
        self.discovery = discovery
        self.pairing = pairing
        self.notification = notification
        self.session = session
        self.share = share
    }
}
