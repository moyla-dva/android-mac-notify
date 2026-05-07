import Foundation

struct LocalRelayReceiverGate: Sendable {
    func prepareInboundRelay(
        deviceId: String,
        registry: inout LocalDeviceRegistry,
        receiverState: RelayState,
        at timestamp: Int64
    ) -> HTTPResponse? {
        registry.updateLastSeen(for: deviceId, at: timestamp, relayState: .active)

        guard receiverState == .paused else {
            return nil
        }
        return LocalHTTPErrorResponses.receiverPaused()
    }
}
