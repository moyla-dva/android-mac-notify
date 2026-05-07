import AppKit
import Foundation

@MainActor
final class AppPairingApprovalPresenter {
    private var shownRequestIds: Set<String> = []

    func reset() {
        shownRequestIds = []
    }

    func presentIfNeeded(
        for request: PairingApprovalRequest,
        onApprove: (PairingApprovalRequest) -> Void,
        onReject: (PairingApprovalRequest) -> Void
    ) {
        guard !shownRequestIds.contains(request.requestId) else {
            return
        }

        shownRequestIds.insert(request.requestId)

        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "允许 Android 设备配对？"
        alert.informativeText = """
        设备名：\(request.device.displayName)
        设备 ID：\(request.device.deviceId)

        允许后，这台 Android 可以向此 Mac 发送通知事件。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "允许")
        alert.addButton(withTitle: "拒绝")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            onApprove(request)
        } else {
            onReject(request)
        }
    }
}
