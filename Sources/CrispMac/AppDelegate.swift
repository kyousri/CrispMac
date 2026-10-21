import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: DisplayController!
    private var settings: SettingsWindowController!
    private var statusItem: StatusItemController!
    private var resetHotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        controller = DisplayController()
        settings = SettingsWindowController(controller: controller)
        statusItem = StatusItemController(controller: controller) { [weak self] in
            self?.settings.show()
        }
        resetHotKey = HotKey(keyCode: kVK_ANSI_0, modifiers: controlKey | optionKey | cmdKey) { [weak self] in
            MainActor.assumeIsolated { self?.controller.resetAllToNative() }
        }

        LoginItem.enableOnFirstLaunch()

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            defaults.set(true, forKey: "hasLaunchedBefore")
            settings.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave an unconfirmed mode behind.
        controller.revertPending()
    }

    /// Only visible while the settings window is open; gives it ⌘W and ⌘Q.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit CrispMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        let menu = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            menu.addItem(item)
        }
        return menu
    }
}
