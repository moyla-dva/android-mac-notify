import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalDeviceAuthenticatorTests {
    @Test
    func testAuthenticatesBearerTokenAndDeviceMatch() throws {
        let authenticator = LocalDeviceAuthenticator()
        let registry = registryWithDevice()

        let deviceId = try authenticator.requireAuthenticatedDeviceId(
            headers: ["authorization": "Bearer token-1"],
            suppliedDeviceId: "android-test",
            registry: registry
        )

        #expect(deviceId == "android-test")
    }

    @Test
    func testInvalidTokenThrowsProtocolErrorResponse() {
        let authenticator = LocalDeviceAuthenticator()
        let registry = registryWithDevice()

        do {
            _ = try authenticator.requireAuthenticatedDeviceId(headers: [:], registry: registry)
            #expect(Bool(false))
        } catch let error as LocalHTTPRequestError {
            #expect(error.response?.statusCode == 401)
        } catch {
            #expect(Bool(false))
        }
    }

    @Test
    func testDeviceMismatchThrowsCustomProtocolErrorResponse() {
        let authenticator = LocalDeviceAuthenticator()
        let registry = registryWithDevice()

        do {
            _ = try authenticator.requireAuthenticatedDeviceId(
                headers: ["authorization": "Bearer token-1"],
                suppliedDeviceId: "other-device",
                registry: registry,
                mismatchMessage: "Device token does not match the requested device ID."
            )
            #expect(Bool(false))
        } catch let error as LocalHTTPRequestError {
            #expect(error.response?.statusCode == 403)
            #expect(error.responseBodyContains("Device token does not match the requested device ID."))
        } catch {
            #expect(Bool(false))
        }
    }

    @Test
    func testMissingRegisteredDeviceThrowsProtocolErrorResponse() {
        let authenticator = LocalDeviceAuthenticator()
        let registry = registryWithDevice()

        do {
            _ = try authenticator.requireRegisteredDevice("missing-device", registry: registry)
            #expect(Bool(false))
        } catch let error as LocalHTTPRequestError {
            #expect(error.response?.statusCode == 404)
        } catch {
            #expect(Bool(false))
        }
    }
}

private func registryWithDevice() -> LocalDeviceRegistry {
    var registry = LocalDeviceRegistry()
    _ = registry.register(
        DeviceIdentity(deviceId: "android-test", platform: "android", displayName: "Phone"),
        at: 100,
        tokenFactory: { "token-1" }
    )
    return registry
}

private extension LocalHTTPRequestError {
    var response: HTTPResponse? {
        if case let .response(response) = self {
            return response
        }
        return nil
    }

    func responseBodyContains(_ value: String) -> Bool {
        guard let response, let body = String(data: response.body, encoding: .utf8) else {
            return false
        }
        return body.contains(value)
    }
}
