import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct AppDiagnosticStateWriterTests {
    @Test
    func testWriteCreatesDiagnosticsJSON() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDiagnosticStateWriterTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let writer = AppDiagnosticStateWriter(directoryURL: directoryURL)
        let error = writer.write(sampleSnapshot())

        #expect(error == nil)

        let diagnosticsURL = directoryURL.appendingPathComponent("runtime-diagnostics.json", isDirectory: false)
        let data = try Data(contentsOf: diagnosticsURL)
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(payload["connectionState"] as? String == "接力可用 OCE-AN10")
        #expect(payload["host"] as? String == "192.168.1.2")
        #expect(payload["pairingTokenPresent"] as? Bool == true)
        #expect(payload["notificationsReceived"] as? Int == 1)
        #expect(payload["lastError"] as? String == "last-error")

        let attributes = try FileManager.default.attributesOfItem(atPath: diagnosticsURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue & 0o777 == 0o600)
    }

    @Test
    func testWriteKeepsNilFieldsAsJSONNull() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDiagnosticStateWriterTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let writer = AppDiagnosticStateWriter(directoryURL: directoryURL)
        var snapshot = sampleSnapshot()
        snapshot = AppDiagnosticStateSnapshot(
            connectionState: .waitingForPair,
            currentHost: snapshot.currentHost,
            currentPort: snapshot.currentPort,
            pairingToken: nil,
            pairingTokenExpiresAt: nil,
            macDeviceId: nil,
            macDisplayName: snapshot.macDisplayName,
            pairedDeviceName: nil,
            statusCard: nil,
            sharedFileReceiveStatus: nil,
            recentStatusCards: [],
            pendingPairingRequests: [],
            notificationsReceived: 0,
            actionFeedbackMessage: nil,
            lastActionResult: nil,
            actionResults: [],
            lastNotificationSummary: nil,
            transientNotifications: [],
            lastError: nil
        )

        let error = writer.write(snapshot)

        #expect(error == nil)

        let diagnosticsURL = directoryURL.appendingPathComponent("runtime-diagnostics.json", isDirectory: false)
        let data = try Data(contentsOf: diagnosticsURL)
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(payload["pairingTokenPresent"] as? Bool == false)
        #expect(payload["pairedDeviceName"] is NSNull)
        #expect(payload["lastNotification"] is NSNull)
    }

    private func sampleSnapshot() -> AppDiagnosticStateSnapshot {
        let action = ActionCandidate(
            actionId: "copy-text",
            sourceEventId: "event-1",
            kind: .copyText,
            title: "复制文本",
            value: "hello",
            priority: .high,
            payload: .text(value: "hello")
        )
        let summary = LocalNotificationSummary(
            eventId: "event-1",
            deviceId: "android-1",
            appPackage: "com.example",
            appName: "Example",
            title: "Title",
            text: "hello",
            receivedAt: 100,
            verificationContext: nil,
            actionCandidates: [action]
        )

        return AppDiagnosticStateSnapshot(
            connectionState: .connected(deviceName: "OCE-AN10"),
            currentHost: "192.168.1.2",
            currentPort: 38471,
            pairingToken: "pair-token",
            pairingTokenExpiresAt: 200,
            macDeviceId: "mac-1",
            macDisplayName: "MacBook",
            pairedDeviceName: "OCE-AN10",
            statusCard: StatusCardState(
                id: "card-1",
                category: .delivery,
                sourceEventId: "event-1",
                appName: "Delivery",
                title: "外卖",
                detail: "配送中",
                stage: .inProgress,
                etaText: "10 分钟",
                updatedAt: 120
            ),
            sharedFileReceiveStatus: SharedFileReceiveStatus(
                transferId: "transfer-1",
                batchId: "batch-1",
                batchIndex: 0,
                batchTotal: 2,
                fileName: "a.txt",
                receivedBytes: 10,
                totalBytes: 20,
                speedBytesPerSecond: 5,
                remainingSeconds: 2,
                stage: .receiving,
                message: "receiving",
                updatedAt: 130
            ),
            recentStatusCards: [],
            pendingPairingRequests: [
                PairingApprovalRequest(
                    requestId: "request-1",
                    device: DeviceIdentity(deviceId: "android-1", platform: "android", displayName: "OCE-AN10"),
                    requestedAt: 90,
                    expiresAt: 190,
                    status: .pending
                ),
            ],
            notificationsReceived: 1,
            actionFeedbackMessage: "done",
            lastActionResult: ActionResult(
                actionId: "copy-text",
                sourceEventId: "event-1",
                status: .success,
                executedAt: 140,
                message: "done"
            ),
            actionResults: [
                ActionResult(
                    actionId: "copy-text",
                    sourceEventId: "event-1",
                    status: .success,
                    executedAt: 140,
                    message: "done"
                ),
            ],
            lastNotificationSummary: summary,
            transientNotifications: [summary],
            lastError: "last-error"
        )
    }
}
