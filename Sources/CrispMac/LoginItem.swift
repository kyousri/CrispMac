import Foundation
import ServiceManagement

/// Launch at login through the standard macOS login items.
enum LoginItem {
    private static let configuredKey = "loginItemConfigured"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Launch at login is on by default; only the very first launch turns it on.
    static func enableOnFirstLaunch(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: configuredKey) else { return }
        defaults.set(true, forKey: configuredKey)
        try? setEnabled(true)
    }
}
