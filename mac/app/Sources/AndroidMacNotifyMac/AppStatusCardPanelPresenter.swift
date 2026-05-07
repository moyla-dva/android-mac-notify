import AppKit
import SwiftUI

@MainActor
final class AppStatusCardPanelPresenter {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(appState: AppState) {
        if let panel {
            position(panel)
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 136),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: StatusFloatingCardView(appState: appState))

        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.close()
        panel = nil
    }

    func cancelScheduledDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    func scheduleCompletedDismiss(
        for card: StatusCardState,
        isCurrentCompleted: @escaping @MainActor @Sendable () -> Bool,
        onDismiss: @escaping @MainActor @Sendable () -> Void
    ) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(300))
            guard isCurrentCompleted() else {
                return
            }
            onDismiss()
        }
    }

    private func position(_ panel: NSPanel) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.maxX - panelSize.width - 24,
            y: visibleFrame.maxY - panelSize.height - 24
        )
        panel.setFrameOrigin(origin)
    }
}
