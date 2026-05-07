import Testing
@testable import AndroidMacNotifyMac

struct AppPairingApprovalProjectionTests {
    @Test
    func testPendingRequestIsInsertedAtFrontWithFeedback() {
        let existing = request(id: "old", deviceName: "Old Phone", status: .pending)
        let incoming = request(id: "new", deviceName: "OCE-AN10", status: .pending)

        let projection = AppPairingApprovalProjector.project(
            request: incoming,
            currentPendingRequests: [existing]
        )

        #expect(projection.pendingPairingRequests.map(\.requestId) == ["new", "old"])
        #expect(projection.actionFeedbackMessage == "OCE-AN10 请求配对")
    }

    @Test
    func testTerminalRequestRemovesExistingPendingRequest() {
        let pending = request(id: "pair-1", deviceName: "OCE-AN10", status: .pending)
        let approved = request(id: "pair-1", deviceName: "OCE-AN10", status: .approved)

        let projection = AppPairingApprovalProjector.project(
            request: approved,
            currentPendingRequests: [pending]
        )

        #expect(projection.pendingPairingRequests.isEmpty)
        #expect(projection.actionFeedbackMessage == "已允许 OCE-AN10 配对")
    }

    @Test
    func testFeedbackMessagesCoverAllTerminalStates() {
        #expect(
            AppPairingApprovalProjector.feedbackMessage(
                for: request(id: "approved", deviceName: "Phone", status: .approved)
            ) == "已允许 Phone 配对"
        )
        #expect(
            AppPairingApprovalProjector.feedbackMessage(
                for: request(id: "rejected", deviceName: "Phone", status: .rejected)
            ) == "已拒绝 Phone 配对"
        )
        #expect(
            AppPairingApprovalProjector.feedbackMessage(
                for: request(id: "expired", deviceName: "Phone", status: .expired)
            ) == "Phone 配对请求已过期"
        )
    }

    private func request(
        id: String,
        deviceName: String,
        status: PairApprovalStatus
    ) -> PairingApprovalRequest {
        PairingApprovalRequest(
            requestId: id,
            device: DeviceIdentity(
                deviceId: "device-\(id)",
                platform: "android",
                displayName: deviceName
            ),
            requestedAt: 100,
            expiresAt: 1_000,
            status: status
        )
    }
}
