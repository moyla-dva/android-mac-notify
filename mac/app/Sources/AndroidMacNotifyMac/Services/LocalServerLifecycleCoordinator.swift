import Foundation

enum LocalServerStartPlan: Equatable, Sendable {
    case reuseRunningServer(endpoint: LocalServerEndpoint, pairingToken: String)
    case startListener(pairingToken: String)
}

struct LocalServerLifecycleCoordinator: Sendable {
    func prepareStart(
        endpoint: LocalServerEndpoint?,
        pairingTokenManager: inout LocalPairingTokenManager,
        now: Int64,
        tokenFactory: @Sendable () -> String
    ) -> LocalServerStartPlan {
        if let endpoint, pairingTokenManager.currentToken != nil {
            let pairingToken = pairingTokenManager.refreshIfNeeded(
                at: now,
                tokenFactory: tokenFactory
            )
            return .reuseRunningServer(endpoint: endpoint, pairingToken: pairingToken)
        }

        let pairingToken = pairingTokenManager.rotate(
            at: now,
            tokenFactory: tokenFactory
        )
        return .startListener(pairingToken: pairingToken)
    }

    func stop(pairingTokenManager: inout LocalPairingTokenManager) {
        pairingTokenManager.clear()
    }

    @discardableResult
    func rotatePairingTokenIfRunning(
        endpoint: LocalServerEndpoint?,
        pairingTokenManager: inout LocalPairingTokenManager,
        now: Int64,
        tokenFactory: @Sendable () -> String
    ) -> String? {
        guard endpoint != nil else {
            return nil
        }
        return pairingTokenManager.rotate(at: now, tokenFactory: tokenFactory)
    }
}
