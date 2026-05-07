import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var appState: AppState?
    private var cancellables: Set<AnyCancellable> = []
    private var autoCloseTask: Task<Void, Never>?

    func configure(appState: AppState) {
        self.appState = appState
        cancellables.removeAll()
        autoCloseTask?.cancel()

        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }

        if popover == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentSize = NSSize(width: 320, height: 440)
            self.popover = popover
        }

        popover?.contentViewController = NSHostingController(
            rootView: StatusMenuView(
                appState: appState,
                onShowMainWindow: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.presentMainWindow()
                    }
                },
                onShowSettings: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.presentSettings()
                    }
                }
            )
        )

        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        appState.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusItem()
            }
        }
        .store(in: &cancellables)

        appState.actionPromptPublisher.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showPopoverForActionPrompt()
            }
        }
        .store(in: &cancellables)

        appState.actionCompletedPublisher.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.closePopoverAfterAction()
            }
        }
        .store(in: &cancellables)

        appState.commandCompletedPublisher.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.closePopoverAfterAction()
            }
        }
        .store(in: &cancellables)

        updateStatusItem()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        let symbolName = appState?.menuSymbolName ?? "bell.badge"
        let fallbackName = "bell.badge"
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Android Mac Notify"
        ) ?? NSImage(
            systemSymbolName: fallbackName,
            accessibilityDescription: "Android Mac Notify"
        )
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = "Android Mac Notify · \(appState?.connectionState.title ?? "未启动")"
        statusItem?.length = NSStatusItem.squareLength
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else {
            return
        }

        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(sender)
            showContextMenu(for: button)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopoverForActionPrompt() {
        autoCloseTask?.cancel()
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem?.button, let popover else {
            return
        }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func closePopoverAfterAction() {
        autoCloseTask?.cancel()
        autoCloseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.popover?.performClose(nil)
        }
    }

    private func performWindowActionAfterClosingPopover(_ action: @escaping @MainActor () -> Void) {
        autoCloseTask?.cancel()
        let shouldDelayForPopoverClose = popover?.isShown == true
        popover?.performClose(nil)

        Task { @MainActor in
            if shouldDelayForPopoverClose {
                try? await Task.sleep(for: .milliseconds(80))
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            action()
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func presentMainWindow() {
        performWindowActionAfterClosingPopover {
            MainWindowPresenter.show(appState: self.appState)
        }
    }

    private func presentSettings() {
        guard let appState else {
            return
        }
        performWindowActionAfterClosingPopover {
            SettingsWindowPresenter.show(appState: appState)
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        let pendingCount = appState?.actionInboxNotifications.count ?? 0

        let pendingItem = NSMenuItem(
            title: pendingCount > 0 ? "\(pendingCount) 条待处理动作" : "没有待处理动作",
            action: nil,
            keyEquivalent: ""
        )
        pendingItem.isEnabled = false
        menu.addItem(pendingItem)
        menu.addItem(.separator())

        let receiverTitle: String
        switch appState?.serverStatus {
        case .running:
            receiverTitle = appState?.isReceiverPaused == true ? "恢复接力" : "暂停接力"
        case .stopped, .failed, .none:
            receiverTitle = "开始接力"
        }
        menu.addItem(menuItem(title: receiverTitle, action: #selector(toggleReceiverFromMenu(_:))))
        menu.addItem(menuItem(title: "打开主窗口", action: #selector(showMainWindowFromMenu(_:))))
        menu.addItem(menuItem(title: "设置...", action: #selector(showSettingsFromMenu(_:))))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "退出 Android Mac Notify", action: #selector(quitFromMenu(_:))))

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        }
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func toggleReceiverFromMenu(_ sender: NSMenuItem) {
        switch appState?.serverStatus {
        case .running:
            appState?.toggleReceiverPause()
        case .stopped, .failed, .none:
            appState?.startLocalServer()
        }
    }

    @objc private func showMainWindowFromMenu(_ sender: NSMenuItem) {
        presentMainWindow()
    }

    @objc private func showSettingsFromMenu(_ sender: NSMenuItem) {
        presentSettings()
    }

    @objc private func quitFromMenu(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
