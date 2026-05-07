import Foundation

final class AppConnectivityMonitor {
    private let networkPathMonitor: AppNetworkPathMonitor
    private let connectionFreshnessScheduler: AppConnectionFreshnessScheduler

    init(
        networkPathMonitor: AppNetworkPathMonitor = AppNetworkPathMonitor(),
        connectionFreshnessScheduler: AppConnectionFreshnessScheduler = AppConnectionFreshnessScheduler()
    ) {
        self.networkPathMonitor = networkPathMonitor
        self.connectionFreshnessScheduler = connectionFreshnessScheduler
    }

    func start(
        onNetworkPathUpdate: @escaping @MainActor (_ isSatisfied: Bool) -> Void,
        onConnectionFreshnessTick: @escaping @MainActor () -> Void
    ) {
        networkPathMonitor.start { isSatisfied in
            Task { @MainActor in
                onNetworkPathUpdate(isSatisfied)
            }
        }
        connectionFreshnessScheduler.start {
            onConnectionFreshnessTick()
        }
    }

    func cancel() {
        networkPathMonitor.cancel()
        connectionFreshnessScheduler.cancel()
    }
}
