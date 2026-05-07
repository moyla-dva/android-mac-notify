import Foundation

struct AppConnectionProjection: Equatable, Sendable {
    let pairedDeviceName: String?
    let connectionState: ConnectionState
}

struct AppConnectionStateProjector: Sendable {
    let staleTimeoutMillis: Int64

    init(staleTimeoutMillis: Int64 = 45_000) {
        self.staleTimeoutMillis = staleTimeoutMillis
    }

    func project(
        devices: [LocalRegisteredDevice],
        isReceiverPaused: Bool,
        now: Int64
    ) -> AppConnectionProjection {
        guard let device = mostRecentDevice(in: devices) else {
            return AppConnectionProjection(
                pairedDeviceName: nil,
                connectionState: .waitingForPair
            )
        }

        return AppConnectionProjection(
            pairedDeviceName: device.displayName,
            connectionState: project(device: device, isReceiverPaused: isReceiverPaused, now: now)
        )
    }

    func project(
        device: LocalRegisteredDevice,
        isReceiverPaused: Bool,
        now: Int64
    ) -> ConnectionState {
        if isReceiverPaused {
            return .macReceiverPaused(deviceName: device.displayName)
        }

        if device.relayState == .paused {
            return .deviceRelayPaused(deviceName: device.displayName)
        }

        if now - device.lastSeenAt > staleTimeoutMillis {
            return .disconnectedRetrying
        }

        return .connected(deviceName: device.displayName)
    }

    func mostRecentDevice(in devices: [LocalRegisteredDevice]) -> LocalRegisteredDevice? {
        devices.max(by: { $0.lastSeenAt < $1.lastSeenAt })
    }
}
