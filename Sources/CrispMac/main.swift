import AppKit
import CrispCore

let app = NSApplication.shared

// Command-line tools for troubleshooting and development. They use the same code as the app.
let arguments = CommandLine.arguments
if arguments.contains("--list") {
    // What each external display offers.
    for display in DisplayService.externalDisplays() {
        let catalog = display.catalog
        let installed = OverrideInstaller.isInstalled(vendor: display.vendor, model: display.model)
        let loaded = DisplayOverride.isLoaded(in: catalog)
        print("\(display.name)  [\(display.key)]")
        print("  extra sizes: \(installed ? (loaded ? "installed, loaded" : "installed, NOT loaded") : "not installed")")
        if let mode = display.currentMode {
            print("  current: \(describeMode(size: mode.size, hiDPI: mode.isHiDPI, refreshRate: mode.refreshRate))")
        }
        for size in catalog.sizes.reversed() {
            let sharp = catalog.refreshRates(for: size, hiDPI: true).map(RefreshRate.format)
            let normal = catalog.refreshRates(for: size, hiDPI: false).map(RefreshRate.format)
            let sharpText = sharp.isEmpty ? "—" : sharp.joined(separator: ", ")
            let normalText = normal.isEmpty ? "—" : normal.joined(separator: ", ")
            print("  \(size)  HiDPI: \(sharpText)  normal: \(normalText)")
        }
    }
    exit(0)
}
if arguments.contains("--print-install-command") || arguments.contains("--print-remove-command") {
    // The root shell commands behind "Add/Remove Extra Sizes", for running with sudo.
    for display in DisplayService.externalDisplays() {
        if arguments.contains("--print-install-command") {
            print(try OverrideInstaller.installCommand(for: display))
        } else {
            print(OverrideInstaller.removeCommand(vendor: display.vendor, model: display.model))
        }
    }
    exit(0)
}
if arguments.contains("--reload") {
    // Turns external displays off and on so macOS re-reads their overrides.
    do {
        try DisplayReloader.reload(DisplayService.externalDisplays().map(\.id))
        print("Reloaded.")
        exit(0)
    } catch {
        print(error.localizedDescription)
        exit(1)
    }
}

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
