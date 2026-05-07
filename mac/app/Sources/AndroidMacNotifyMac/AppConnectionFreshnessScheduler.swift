import Foundation

final class AppConnectionFreshnessScheduler {
    private let interval: Duration
    private var task: Task<Void, Never>?

    init(interval: Duration = .seconds(15)) {
        self.interval = interval
    }

    deinit {
        task?.cancel()
    }

    func start(onTick: @escaping @MainActor @Sendable () -> Void) {
        cancel()
        task = Task { @MainActor [interval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else {
                    return
                }
                onTick()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
