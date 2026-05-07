import Foundation

struct LocalDeviceRegistry: Sendable {
    private var registeredDevicesById: [String: LocalRegisteredDevice] = [:]
    private var deviceIdByToken: [String: String] = [:]

    init(devices: [LocalRegisteredDevice] = []) {
        replace(with: devices)
    }

    var count: Int {
        registeredDevicesById.count
    }

    func authenticate(headers: [String: String]) -> String? {
        guard let authorization = headers["authorization"] else {
            return nil
        }

        let prefix = "Bearer "
        guard authorization.hasPrefix(prefix) else {
            return nil
        }

        let token = String(authorization.dropFirst(prefix.count))
        return deviceIdByToken[token]
    }

    func device(withId deviceId: String) -> LocalRegisteredDevice? {
        registeredDevicesById[deviceId]
    }

    func currentRegisteredDevices() -> [LocalRegisteredDevice] {
        registeredDevicesById.values.sorted { $0.deviceId < $1.deviceId }
    }

    func sessionState(
        for deviceId: String,
        receiverState: RelayState,
        now: Int64,
        connectedTimeoutMillis: Int64 = 45_000
    ) -> String {
        guard let device = registeredDevicesById[deviceId] else {
            return "unpaired"
        }

        if receiverState == .paused {
            return "mac_paused"
        }

        if device.relayState == .paused {
            return "paused"
        }

        let age = now - device.lastSeenAt
        return age <= connectedTimeoutMillis ? "connected" : "disconnected_retrying"
    }

    mutating func replace(with devices: [LocalRegisteredDevice]) {
        registeredDevicesById = [:]
        for device in devices {
            registeredDevicesById[device.deviceId] = device
        }
        rebuildTokenIndex()
    }

    mutating func removeAll() {
        registeredDevicesById.removeAll()
        deviceIdByToken.removeAll()
    }

    mutating func register(
        _ device: DeviceIdentity,
        at timestamp: Int64,
        reuseExistingToken: Bool = false,
        tokenFactory: () -> String
    ) -> LocalRegisteredDevice {
        let deviceToken: String
        if reuseExistingToken, let existing = registeredDevicesById[device.deviceId] {
            deviceToken = existing.deviceToken
        } else {
            deviceToken = tokenFactory()
        }

        let registeredDevice = LocalRegisteredDevice(
            deviceId: device.deviceId,
            platform: device.platform,
            displayName: device.displayName,
            deviceToken: deviceToken,
            lastSeenAt: timestamp,
            relayState: .active
        )

        registeredDevicesById[registeredDevice.deviceId] = registeredDevice
        rebuildTokenIndex()
        return registeredDevice
    }

    @discardableResult
    mutating func updateLastSeen(
        for deviceId: String,
        at timestamp: Int64,
        relayState: RelayState? = nil
    ) -> LocalRegisteredDevice? {
        guard var device = registeredDevicesById[deviceId] else {
            return nil
        }

        device.lastSeenAt = timestamp
        if let relayState {
            device.relayState = relayState
        }
        registeredDevicesById[deviceId] = device
        return device
    }

    mutating func removeDevice(deviceId: String) -> LocalRegisteredDevice? {
        guard let removedDevice = registeredDevicesById.removeValue(forKey: deviceId) else {
            return nil
        }

        deviceIdByToken.removeValue(forKey: removedDevice.deviceToken)
        return removedDevice
    }

    private mutating func rebuildTokenIndex() {
        var tokenIndex: [String: String] = [:]
        for device in registeredDevicesById.values {
            tokenIndex[device.deviceToken] = device.deviceId
        }
        deviceIdByToken = tokenIndex
    }
}
