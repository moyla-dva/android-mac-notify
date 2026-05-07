import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalServerLifecycleCoordinatorTests {
    @Test
    func testPrepareStartForStoppedServerRotatesTokenAndStartsListener() {
        let coordinator = LocalServerLifecycleCoordinator()
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)

        let plan = coordinator.prepareStart(
            endpoint: nil,
            pairingTokenManager: &tokenManager,
            now: 10,
            tokenFactory: { "pair-1" }
        )

        #expect(plan == .startListener(pairingToken: "pair-1"))
        #expect(tokenManager.currentToken == "pair-1")
        #expect(tokenManager.expiresAt(defaultNow: 10) == 110)
    }

    @Test
    func testPrepareStartForRunningServerReusesValidToken() {
        let coordinator = LocalServerLifecycleCoordinator()
        let endpoint = LocalServerEndpoint(host: "127.0.0.1", port: 38471)
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = tokenManager.rotate(at: 10, tokenFactory: { "pair-1" })

        let plan = coordinator.prepareStart(
            endpoint: endpoint,
            pairingTokenManager: &tokenManager,
            now: 50,
            tokenFactory: { "pair-2" }
        )

        #expect(plan == .reuseRunningServer(endpoint: endpoint, pairingToken: "pair-1"))
        #expect(tokenManager.currentToken == "pair-1")
    }

    @Test
    func testPrepareStartForRunningServerRotatesExpiredTokenWithoutStartingNewListener() {
        let coordinator = LocalServerLifecycleCoordinator()
        let endpoint = LocalServerEndpoint(host: "127.0.0.1", port: 38471)
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = tokenManager.rotate(at: 10, tokenFactory: { "pair-1" })

        let plan = coordinator.prepareStart(
            endpoint: endpoint,
            pairingTokenManager: &tokenManager,
            now: 110,
            tokenFactory: { "pair-2" }
        )

        #expect(plan == .reuseRunningServer(endpoint: endpoint, pairingToken: "pair-2"))
        #expect(tokenManager.currentToken == "pair-2")
    }

    @Test
    func testStopClearsToken() {
        let coordinator = LocalServerLifecycleCoordinator()
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = tokenManager.rotate(at: 10, tokenFactory: { "pair-1" })

        coordinator.stop(pairingTokenManager: &tokenManager)

        #expect(tokenManager.currentToken == nil)
    }

    @Test
    func testRotatePairingTokenOnlyWhenServerIsRunning() {
        let coordinator = LocalServerLifecycleCoordinator()
        let endpoint = LocalServerEndpoint(host: "127.0.0.1", port: 38471)
        var tokenManager = LocalPairingTokenManager(lifetimeMillis: 100)

        let stoppedToken = coordinator.rotatePairingTokenIfRunning(
            endpoint: nil,
            pairingTokenManager: &tokenManager,
            now: 10,
            tokenFactory: { "pair-stopped" }
        )
        let runningToken = coordinator.rotatePairingTokenIfRunning(
            endpoint: endpoint,
            pairingTokenManager: &tokenManager,
            now: 20,
            tokenFactory: { "pair-running" }
        )

        #expect(stoppedToken == nil)
        #expect(runningToken == "pair-running")
        #expect(tokenManager.currentToken == "pair-running")
    }
}
