import Foundation

struct LocalDeviceAuthenticator: Sendable {
    func requireAuthenticatedDeviceId(
        headers: [String: String],
        registry: LocalDeviceRegistry
    ) throws -> String {
        guard let authenticatedDeviceId = registry.authenticate(headers: headers) else {
            throw LocalHTTPRequestError.response(LocalHTTPErrorResponses.invalidDeviceToken())
        }
        return authenticatedDeviceId
    }

    func requireAuthenticatedDeviceId(
        headers: [String: String],
        suppliedDeviceId: String,
        registry: LocalDeviceRegistry,
        mismatchMessage: String = "Device token does not match the supplied device ID."
    ) throws -> String {
        let authenticatedDeviceId = try requireAuthenticatedDeviceId(headers: headers, registry: registry)
        try requireDeviceMatch(
            suppliedDeviceId,
            authenticatedDeviceId: authenticatedDeviceId,
            mismatchMessage: mismatchMessage
        )
        return authenticatedDeviceId
    }

    func requireDeviceMatch(
        _ deviceId: String,
        authenticatedDeviceId: String,
        mismatchMessage: String = "Device token does not match the supplied device ID."
    ) throws {
        guard deviceId == authenticatedDeviceId else {
            throw LocalHTTPRequestError.response(
                LocalHTTPErrorResponses.deviceTokenDeviceMismatch(message: mismatchMessage)
            )
        }
    }

    func requireRegisteredDevice(
        _ deviceId: String,
        registry: LocalDeviceRegistry
    ) throws -> LocalRegisteredDevice {
        guard let device = registry.device(withId: deviceId) else {
            throw LocalHTTPRequestError.response(LocalHTTPErrorResponses.deviceNotRegistered())
        }
        return device
    }
}
