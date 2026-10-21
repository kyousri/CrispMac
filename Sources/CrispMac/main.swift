import AppKit
import CrispCore

let app = NSApplication.shared

// `CrispMac --list` prints what each external display offers, for troubleshooting.
if CommandLine.arguments.contains("--list") {
    for display in DisplayService.externalDisplays() {
        let catalog = display.catalog
        print("\(display.name)  [\(display.key)]")
        if let mode = display.currentMode {
            print("  current: \(describeMode(size: mode.size, hiDPI: mode.isHiDPI, refreshRate: mode.refreshRate))")
        }
        for size in catalog.sizes.reversed() {
            let sharp = catalog.refreshRates(for: size, hiDPI: true).map(RefreshRate.format)
            let normal = catalog.refreshRates(for: size, hiDPI: false).map(RefreshRate.format)
            let sharpText = sharp.isEmpty ? "—" : sharp.joined(separator: ", ")
            print("  \(size)  HiDPI: \(sharpText)  normal: \(normal.joined(separator: ", "))")
        }
    }
    exit(0)
}

MainActor.assumeIsolated {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
