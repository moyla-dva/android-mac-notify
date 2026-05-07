import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct LocalPairingTokenManagerTests {
    @Test
    func testRotateSetsTokenAndExpiration() {
        var manager = LocalPairingTokenManager(lifetimeMillis: 100)

        let token = manager.rotate(at: 10, tokenFactory: { "pair-1" })

        #expect(token == "pair-1")
        #expect(manager.currentToken == "pair-1")
        #expect(manager.expiresAt(defaultNow: 10) == 110)
        #expect(manager.isValid("pair-1", at: 109))
        #expect(!manager.isValid("pair-1", at: 110))
        #expect(!manager.isValid("pair-other", at: 109))
    }

    @Test
    func testRefreshReusesValidTokenAndRotatesExpiredToken() {
        var manager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = manager.rotate(at: 10, tokenFactory: { "pair-1" })

        let reused = manager.refreshIfNeeded(at: 50, tokenFactory: { "pair-2" })
        let rotated = manager.refreshIfNeeded(at: 110, tokenFactory: { "pair-2" })

        #expect(reused == "pair-1")
        #expect(rotated == "pair-2")
        #expect(manager.currentToken == "pair-2")
        #expect(manager.expiresAt(defaultNow: 110) == 210)
    }

    @Test
    func testClearInvalidatesToken() {
        var manager = LocalPairingTokenManager(lifetimeMillis: 100)
        _ = manager.rotate(at: 10, tokenFactory: { "pair-1" })

        manager.clear()

        #expect(manager.currentToken == nil)
        #expect(!manager.isValid("pair-1", at: 20))
        #expect(manager.expiresAt(defaultNow: 20) == 120)
    }
}
