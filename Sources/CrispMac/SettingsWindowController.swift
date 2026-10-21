import AppKit
import SwiftUI

/// The settings window. The app shows a Dock icon only while it is open.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let controller: DisplayController
    private var window: NSWindow?

    init(controller: DisplayController) {
        self.controller = controller
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller)))
        window.title = "CrispMac"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
