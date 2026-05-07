import Foundation

struct AppDeviceSessionProjection: Equatable, Sendable {
    let registeredDevices: [LocalRegisteredDevice]
    let pairedDeviceName: String?
    let connectionState: ConnectionState
}

enum AppDeviceSessionProjector {
    static func registered(
        device: LocalRegisteredDevice,
        existingDevices: [LocalRegisteredDevice],
        isReceiverPaused: Bool,
        now: Int64,
        connectionStateProjector: AppConnectionStateProjector
    ) -> AppDeviceSessionProjection {
        let devices = upserting(device, into: existingDevices)
        return AppDeviceSessionProjection(
            registeredDevices: devices,
            pairedDeviceName: device.displayName,
            connectionState: connectionStateProjector.project(
                device: device,
                isReceiverPaused: isReceiverPaused,
                now: now
            )
        )
    }

    static func heartbeat(
        deviceId: String,
        at: Int64,
        existingDevices: [LocalRegisteredDevice],
        currentPairedDeviceName: String?,
        currentConnectionState: ConnectionState,
        isReceiverPaused: Bool,
        connectionStateProjector: AppConnectionStateProjector
    ) -> AppDeviceSessionProjection {
        let devices = existingDevices.map { device in
            guard device.deviceId == deviceId else {
                return device
            }

            var updatedDevice = device
            updatedDevice.lastSeenAt = at
            updatedDevice.relayState = .active
            return updatedDevice
        }

        guard let mostRecentDevice = connectionStateProjector.mostRecentDevice(in: devices) else {
            return AppDeviceSessionProjection(
                registeredDevices: devices,
                pairedDeviceName: currentPairedDeviceName,
                connectionState: currentConnectionState
            )
        }

        return AppDeviceSessionProjection(
            registeredDevices: devices,
            pairedDeviceName: mostRecentDevice.displayName,
            connectionState: connectionStateProjector.project(
                device: mostRecentDevice,
                isReceiverPaused: isReceiverPaused,
                now: at
            )
        )
    }

    static func unregistered(
        deviceId: String,
        existingDevices: [LocalRegisteredDevice],
        isReceiverPaused: Bool,
        now: Int64,
        connectionStateProjector: AppConnectionStateProjector
    ) -> AppDeviceSessionProjection {
        let devices = existingDevices.filter { $0.deviceId != deviceId }
        let projection = connectionStateProjector.project(
            devices: devices,
            isReceiverPaused: isReceiverPaused,
            now: now
        )

        return AppDeviceSessionProjection(
            registeredDevices: devices,
            pairedDeviceName: projection.pairedDeviceName,
            connectionState: projection.connectionState
        )
    }

    private static func upserting(
        _ device: LocalRegisteredDevice,
        into devices: [LocalRegisteredDevice]
    ) -> [LocalRegisteredDevice] {
        devices.filter { $0.deviceId != device.deviceId } + [device]
    }
}
