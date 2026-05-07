import Foundation
import Network

final class AppNetworkPathMonitor {
    typealias PathUpdateHandler = @Sendable (_ isSatisfied: Bool) -> Void

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    init(
        monitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(label: "AndroidMacNotifyMac.PathMonitor")
    ) {
        self.monitor = monitor
        self.queue = queue
    }

    deinit {
        monitor.cancel()
    }

    func start(onPathUpdate: @escaping PathUpdateHandler) {
        monitor.pathUpdateHandler = { path in
            onPathUpdate(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}
