import Foundation
import Network

struct LocalServerListenerFactory: Sendable {
    private final class ListenerStartBox: @unchecked Sendable {
        var hasResumed = false
    }

    struct StartedListener {
        let listener: NWListener
        let endpoint: LocalServerEndpoint
    }

    let discoveryProtocolVersion: Int
    let bonjourServiceType: String

    func start(
        host: String,
        port: Int,
        macDeviceId: String,
        macDisplayName: String,
        onConnection: @escaping @Sendable (NWConnection) -> Void,
        onFailedAfterReady: @escaping @Sendable (String) -> Void
    ) async throws -> StartedListener {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw LocalServerError.invalidPort
        }

        let listener = try NWListener(using: .tcp, on: nwPort)
        listener.service = NWListener.Service(
            name: macDisplayName,
            type: bonjourServiceType,
            txtRecord: NWTXTRecord([
                "pv": "\(discoveryProtocolVersion)",
                "id": macDeviceId,
            ])
        )

        let listenerQueue = DispatchQueue(label: "AndroidMacNotifyMac.LocalServer.Listener")
        let startBox = ListenerStartBox()

        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak listener] state in
                switch state {
                case .ready:
                    if startBox.hasResumed {
                        return
                    }
                    guard let readyListener = listener else {
                        startBox.hasResumed = true
                        continuation.resume(throwing: LocalServerError.failedToStart("Listener was released before it became ready."))
                        return
                    }
                    startBox.hasResumed = true
                    continuation.resume(
                        returning: StartedListener(
                            listener: readyListener,
                            endpoint: LocalServerEndpoint(
                                host: host,
                                port: Int(readyListener.port?.rawValue ?? nwPort.rawValue)
                            )
                        )
                    )
                case let .failed(error):
                    if startBox.hasResumed {
                        onFailedAfterReady(error.localizedDescription)
                        return
                    }
                    startBox.hasResumed = true
                    continuation.resume(throwing: LocalServerError.failedToStart(error.localizedDescription))
                default:
                    break
                }
            }

            listener.newConnectionHandler = onConnection
            listener.start(queue: listenerQueue)
        }
    }
}
