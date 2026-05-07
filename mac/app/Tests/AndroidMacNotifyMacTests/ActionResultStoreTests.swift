import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct ActionResultStoreTests {
    @Test
    func testRetainedResultsKeepOnlySanitizedRecentSuccesses() {
        let now: Int64 = 1_777_875_700_000
        let recentSuccess = ActionResult(
            actionId: "act_recent_copy-verification-code",
            sourceEventId: "event-recent",
            status: .success,
            executedAt: now - 1_000,
            message: "已复制验证码 864219"
        )
        let failedResult = ActionResult(
            actionId: "act_failed_open-link",
            sourceEventId: "event-failed",
            status: .failed,
            executedAt: now - 500,
            message: "打开链接失败"
        )
        let expiredSuccess = ActionResult(
            actionId: "act_expired_copy-text",
            sourceEventId: "event-expired",
            status: .success,
            executedAt: now - ActionResultStore.maxStoredAgeMillis - 1,
            message: "已复制文本"
        )

        let retainedResults = ActionResultStore.retainedResults(
            from: [recentSuccess, failedResult, expiredSuccess],
            now: now
        )

        #expect(retainedResults == [
            ActionResult(
                actionId: recentSuccess.actionId,
                sourceEventId: recentSuccess.sourceEventId,
                status: .success,
                executedAt: recentSuccess.executedAt,
                message: nil
            ),
        ])
    }

    @Test
    func testRetainedResultsKeepLatestDuplicateAction() {
        let now: Int64 = 1_777_875_700_000
        let older = ActionResult(
            actionId: "act_duplicate_open-link",
            sourceEventId: "event-duplicate",
            status: .success,
            executedAt: now - 3_000,
            message: nil
        )
        let newer = ActionResult(
            actionId: older.actionId,
            sourceEventId: older.sourceEventId,
            status: .success,
            executedAt: now - 1_000,
            message: "已打开链接"
        )

        let retainedResults = ActionResultStore.retainedResults(from: [older, newer], now: now)

        #expect(retainedResults == [
            ActionResult(
                actionId: newer.actionId,
                sourceEventId: newer.sourceEventId,
                status: .success,
                executedAt: newer.executedAt,
                message: nil
            ),
        ])
    }

    @Test
    func testStoreRoundTripWritesSanitizedResults() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifyMacTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("action-results.json", isDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }

        let now: Int64 = 1_777_875_700_000
        let store = ActionResultStore(fileURL: fileURL)
        let result = ActionResult(
            actionId: "act_roundtrip_copy-text",
            sourceEventId: "event-roundtrip",
            status: .success,
            executedAt: now,
            message: "已复制文本"
        )

        try await store.save([result], now: now)
        let loadedResults = try await store.load(now: now)

        #expect(loadedResults == [
            ActionResult(
                actionId: result.actionId,
                sourceEventId: result.sourceEventId,
                status: .success,
                executedAt: result.executedAt,
                message: nil
            ),
        ])
    }
}
