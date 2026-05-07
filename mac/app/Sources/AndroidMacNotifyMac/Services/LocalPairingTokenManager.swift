import Foundation

struct LocalPairingTokenManager: Sendable {
    private let lifetimeMillis: Int64
    private var token: String?
    private var issuedAt: Int64?

    init(lifetimeMillis: Int64) {
        self.lifetimeMillis = lifetimeMillis
    }

    var currentToken: String? {
        token
    }

    func expiresAt(defaultNow now: Int64) -> Int64 {
        (issuedAt ?? now) + lifetimeMillis
    }

    func isValid(_ candidate: String, at now: Int64) -> Bool {
        guard let token, candidate == token else {
            return false
        }
        return expiresAt(defaultNow: now) > now
    }

    mutating func clear() {
        token = nil
        issuedAt = nil
    }

    mutating func rotate(
        at timestamp: Int64,
        tokenFactory: @Sendable () -> String
    ) -> String {
        let token = tokenFactory()
        self.token = token
        issuedAt = timestamp
        return token
    }

    mutating func refreshIfNeeded(
        at timestamp: Int64,
        tokenFactory: @Sendable () -> String
    ) -> String {
        guard let token, expiresAt(defaultNow: timestamp) > timestamp else {
            return rotate(at: timestamp, tokenFactory: tokenFactory)
        }
        return token
    }
}
