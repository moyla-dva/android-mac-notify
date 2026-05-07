import AppKit
import Foundation

@MainActor
enum ActionExecutor {
    static func execute(_ action: ActionCandidate) -> ActionResult {
        switch action.kind {
        case .copyVerificationCode:
            return copyVerificationCode(action)
        case .openLink:
            return openLink(action)
        case .copyText:
            return copyText(action)
        case .openFile:
            return openFile(action)
        case .revealFile:
            return revealFile(action)
        case .copyFilePath:
            return copyFilePath(action)
        case .showNotification, .recordHistory:
            return result(
                for: action,
                status: .failed,
                message: "这个动作暂时不需要手动执行"
            )
        }
    }

    private static func copyVerificationCode(_ action: ActionCandidate) -> ActionResult {
        guard let code = action.verificationCode, !code.isEmpty else {
            return result(for: action, status: .failed, message: "当前通知没有可复制的验证码")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(code, forType: .string)

        return result(
            for: action,
            status: didCopy ? .success : .failed,
            message: didCopy ? "已复制验证码 \(code)" : "复制验证码失败"
        )
    }

    private static func openLink(_ action: ActionCandidate) -> ActionResult {
        guard let rawURL = action.linkURLString, let url = normalizedURL(from: rawURL) else {
            return result(for: action, status: .failed, message: "当前通知没有可打开的链接")
        }

        let didOpen = NSWorkspace.shared.open(url)
        return result(
            for: action,
            status: didOpen ? .success : .failed,
            message: didOpen ? "已打开链接" : "打开链接失败"
        )
    }

    private static func copyText(_ action: ActionCandidate) -> ActionResult {
        guard let text = action.textValue, !text.isEmpty else {
            return result(for: action, status: .failed, message: "当前通知没有可复制的文本")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(text, forType: .string)

        return result(
            for: action,
            status: didCopy ? .success : .failed,
            message: didCopy ? "已复制文本" : "复制文本失败"
        )
    }

    private static func openFile(_ action: ActionCandidate) -> ActionResult {
        guard let file = action.fileValue else {
            return result(for: action, status: .failed, message: "当前动作没有文件路径")
        }

        let url = URL(fileURLWithPath: file.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return result(for: action, status: .failed, message: "文件不存在")
        }

        let didOpen = NSWorkspace.shared.open(url)
        return result(
            for: action,
            status: didOpen ? .success : .failed,
            message: didOpen ? "已打开文件" : "打开文件失败"
        )
    }

    private static func revealFile(_ action: ActionCandidate) -> ActionResult {
        guard let file = action.fileValue else {
            return result(for: action, status: .failed, message: "当前动作没有文件路径")
        }

        let url = URL(fileURLWithPath: file.path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return result(for: action, status: .failed, message: "文件不存在")
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        return result(for: action, status: .success, message: "已在 Finder 中显示")
    }

    private static func copyFilePath(_ action: ActionCandidate) -> ActionResult {
        guard let file = action.fileValue, !file.path.isEmpty else {
            return result(for: action, status: .failed, message: "当前动作没有文件路径")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(file.path, forType: .string)

        return result(
            for: action,
            status: didCopy ? .success : .failed,
            message: didCopy ? "已复制文件路径" : "复制文件路径失败"
        )
    }

    private static func normalizedURL(from rawURL: String) -> URL? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

    private static func result(
        for action: ActionCandidate,
        status: ActionExecutionStatus,
        message: String?
    ) -> ActionResult {
        ActionResult(
            actionId: action.actionId,
            sourceEventId: action.sourceEventId,
            status: status,
            executedAt: Int64(Date().timeIntervalSince1970 * 1000),
            message: message
        )
    }
}
