import AppKit
import Foundation

struct AppCommandResult: Equatable {
    let feedbackMessage: String
    let errorMessage: String?

    init(feedbackMessage: String, errorMessage: String? = nil) {
        self.feedbackMessage = feedbackMessage
        self.errorMessage = errorMessage
    }
}

@MainActor
final class AppSharedFileCommandController {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savedDirectoryPath(forKey defaultsKey: String) -> String? {
        defaults.string(forKey: defaultsKey)
    }

    func chooseSaveDirectory(currentDirectoryURL: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "选择文件投递保存位置"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentDirectoryURL

        guard panel.runModal() == .OK, let directoryURL = panel.url else {
            return nil
        }

        return directoryURL
    }

    func storeSaveDirectory(_ directoryURL: URL?, defaultsKey: String) -> String? {
        let standardizedPath = directoryURL?.standardizedFileURL.path
        if let standardizedPath {
            defaults.set(standardizedPath, forKey: defaultsKey)
        } else {
            defaults.removeObject(forKey: defaultsKey)
        }
        return standardizedPath
    }

    func revealSaveDirectory(_ directoryURL: URL) -> AppCommandResult {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([directoryURL])
            return AppCommandResult(feedbackMessage: "已在 Finder 中显示保存位置")
        } catch {
            return AppCommandResult(
                feedbackMessage: "打开保存位置失败",
                errorMessage: error.localizedDescription
            )
        }
    }

    func revealDeliveryGroup(_ group: SharedFileDeliveryGroup) -> AppCommandResult {
        let urls = existingFileURLs(in: group)

        guard !urls.isEmpty else {
            return AppCommandResult(feedbackMessage: "找不到这批文件")
        }

        NSWorkspace.shared.activateFileViewerSelecting(urls)
        return AppCommandResult(
            feedbackMessage: urls.count == 1
                ? "已在 Finder 中显示文件"
                : "已在 Finder 中显示 \(urls.count) 个文件"
        )
    }

    func copyDeliveryGroupPaths(_ group: SharedFileDeliveryGroup) -> AppCommandResult {
        let paths = group.savedFilePaths
        guard !paths.isEmpty else {
            return AppCommandResult(feedbackMessage: "这批文件没有可复制的路径")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(paths.joined(separator: "\n"), forType: .string)

        return AppCommandResult(
            feedbackMessage: didCopy
                ? "已复制 \(paths.count) 个文件路径"
                : "复制文件路径失败"
        )
    }

    private func existingFileURLs(in group: SharedFileDeliveryGroup) -> [URL] {
        group.savedFilePaths
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
