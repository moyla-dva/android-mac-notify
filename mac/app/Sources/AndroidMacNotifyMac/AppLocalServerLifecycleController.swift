import Foundation

final class AppLocalServerLifecycleController {
    typealias SnapshotHandler = @MainActor @Sendable (LocalServerSnapshot) -> Void
    typealias OptionalSnapshotHandler = @MainActor @Sendable (LocalServerSnapshot?) -> Void
    typealias StoppedHandler = @MainActor @Sendable () -> Void
    typealias FailureHandler = @MainActor @Sendable (_ message: String) -> Void

    private let localServer: LocalServer
    private var networkRestartTask: Task<Void, Never>?

    init(localServer: LocalServer) {
        self.localServer = localServer
    }

    deinit {
        networkRestartTask?.cancel()
    }

    func start(
        host: String,
        port: Int,
        onSuccess: @escaping SnapshotHandler,
        onFailure: @escaping FailureHandler
    ) {
        Task { [localServer] in
            do {
                let snapshot = try await localServer.start(host: host, port: port)
                await onSuccess(snapshot)
            } catch {
                await onFailure(error.localizedDescription)
            }
        }
    }

    func stop(onStopped: @escaping StoppedHandler) {
        Task { [localServer] in
            await localServer.stop()
            await onStopped()
        }
    }

    func setReceiverPaused(
        _ isPaused: Bool,
        onUpdated: @escaping OptionalSnapshotHandler
    ) {
        Task { [localServer] in
            let snapshot = await localServer.setReceiverPaused(isPaused)
            await onUpdated(snapshot)
        }
    }

    func restartForNetworkChange(
        host: String,
        port: Int,
        shouldRestorePaused: Bool,
        onSuccess: @escaping SnapshotHandler,
        onFailure: @escaping FailureHandler
    ) {
        networkRestartTask?.cancel()
        networkRestartTask = Task { [localServer] in
            await localServer.stop()
            do {
                let snapshot = try await localServer.start(host: host, port: port)
                if shouldRestorePaused {
                    _ = await localServer.setReceiverPaused(true)
                }
                await onSuccess(snapshot)
            } catch {
                await onFailure(error.localizedDescription)
            }
        }
    }
}
