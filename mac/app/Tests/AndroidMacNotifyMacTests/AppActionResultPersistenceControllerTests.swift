import Foundation
import Testing
@testable import AndroidMacNotifyMac

struct AppActionResultPersistenceControllerTests {
    @Test
    func testSaveAndLoadResultsByIdRoundTrip() async throws {
        let fileURL = temporaryFileURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let controller = AppActionResultPersistenceController(
            store: ActionResultStore(fileURL: fileURL)
        )
        let result = actionResult(actionId: "action-copy", sourceEventId: "event-copy")

        let saveError = await controller.save([result.actionId: result])
        let loadOutcome = await controller.loadResultsById()

        #expect(saveError == nil)
        #expect(loadOutcome == .loaded([
            result.actionId: ActionResult(
                actionId: result.actionId,
                sourceEventId: result.sourceEventId,
                status: .success,
                executedAt: result.executedAt,
                message: nil
            ),
        ]))
    }

    @Test
    func testClearRemovesPersistedResults() async throws {
        let fileURL = temporaryFileURL()
        defer {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }

        let controller = AppActionResultPersistenceController(
            store: ActionResultStore(fileURL: fileURL)
        )
        let result = actionResult(actionId: "action-open-link", sourceEventId: "event-link")

        _ = await controller.save([result.actionId: result])
        let clearError = await controller.clear()
        let loadOutcome = await controller.loadResultsById()

        #expect(clearError == nil)
        #expect(loadOutcome == .loaded([:]))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidMacNotifyMacTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("action-results.json", isDirectory: false)
    }

    private func actionResult(actionId: String, sourceEventId: String) -> ActionResult {
        ActionResult(
            actionId: actionId,
            sourceEventId: sourceEventId,
            status: .success,
            executedAt: Int64(Date().timeIntervalSince1970 * 1000),
            message: "已执行"
        )
    }
}
