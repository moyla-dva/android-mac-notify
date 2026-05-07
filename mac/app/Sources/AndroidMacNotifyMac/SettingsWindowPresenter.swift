import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var settingsWindow: NSWindow?
    private static var settingsWindowDelegate: SettingsWindowLifecycleDelegate?

    static func show(appState: AppState) {
        if let settingsWindow {
            if settingsWindow.isMiniaturized {
                settingsWindow.deminiaturize(nil)
            }
            bringWindowToFront(settingsWindow)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView(appState: appState)
                .frame(minWidth: 640, minHeight: 600)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("AndroidMacNotifySettingsWindow")
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.setFrameAutosaveName("AndroidMacNotifySettingsWindow")
        window.center()
        let lifecycleDelegate = SettingsWindowLifecycleDelegate()
        window.delegate = lifecycleDelegate
        settingsWindowDelegate = lifecycleDelegate
        settingsWindow = window
        bringWindowToFront(window)
    }

    fileprivate static func clearSettingsWindow(_ window: NSWindow?) {
        guard window == nil || window === settingsWindow else {
            return
        }
        settingsWindow = nil
        settingsWindowDelegate = nil
    }

    private static func bringWindowToFront(_ window: NSWindow) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private final class SettingsWindowLifecycleDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let window = notification.object as? NSWindow
        Task { @MainActor in
            SettingsWindowPresenter.clearSettingsWindow(window)
        }
    }
}

@MainActor
enum MainWindowPresenter {
    private static weak var fallbackMainWindow: NSWindow?

    static func show(appState: AppState? = nil) {
        if let mainWindow = NSApplication.shared.windows.first(where: { $0.title == "Android Mac Notify" }) {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        guard let appState else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        if let fallbackMainWindow {
            if fallbackMainWindow.isMiniaturized {
                fallbackMainWindow.deminiaturize(nil)
            }
            fallbackMainWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: DashboardView(appState: appState))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Android Mac Notify"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("AndroidMacNotifyMainWindow")
        window.center()
        fallbackMainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
