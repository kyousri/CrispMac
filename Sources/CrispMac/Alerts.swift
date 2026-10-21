import AppKit

@MainActor
enum Alerts {
    /// Asked every time, before screens go black.
    static func confirmReload() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Your external displays will go black for a few seconds"
        alert.informativeText = "CrispMac turns them off and on so macOS loads the display sizes. Windows may move between screens."
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func show(_ error: Error, title: String) {
        if case OverrideInstaller.Failure.cancelled = error { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        NSApp.activate()
        alert.runModal()
    }
}
