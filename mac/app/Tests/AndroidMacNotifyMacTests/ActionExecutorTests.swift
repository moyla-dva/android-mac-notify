import AppKit
import Foundation
import Testing
@testable import AndroidMacNotifyMac

@MainActor
struct ActionExecutorTests {
    @Test
    func testCopyFilePathActionCopiesPath() {
        let path = "/Users/test/Downloads/Android Mac Notify/photo.jpg"
        let action = fileAction(kind: .copyFilePath, path: path)

        let result = ActionExecutor.execute(action)

        #expect(result.status == .success)
        #expect(result.message == "已复制文件路径")
        #expect(NSPasteboard.general.string(forType: .string) == path)
    }

    @Test
    func testOpenFileActionFailsWhenFileIsMissing() {
        let action = fileAction(kind: .openFile, path: "/tmp/android-mac-notify-missing-file.jpg")

        let result = ActionExecutor.execute(action)

        #expect(result.status == .failed)
        #expect(result.message == "文件不存在")
    }

    @Test
    func testRevealFileActionFailsWhenFileIsMissing() {
        let action = fileAction(kind: .revealFile, path: "/tmp/android-mac-notify-missing-file.jpg")

        let result = ActionExecutor.execute(action)

        #expect(result.status == .failed)
        #expect(result.message == "文件不存在")
    }

    private func fileAction(kind: ActionKind, path: String) -> ActionCandidate {
        ActionCandidate(
            actionId: "act_test_\(kind.rawValue)",
            sourceEventId: "event-test",
            kind: kind,
            title: "文件动作",
            value: path,
            priority: .medium,
            payload: .file(path: path, fileName: "photo.jpg", mimeType: "image/jpeg")
        )
    }
}
