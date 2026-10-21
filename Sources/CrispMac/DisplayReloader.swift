import CoreGraphics
import Foundation

/// Turns displays off and on in software so macOS re-reads their override files,
/// the same as unplugging and replugging them. Screens go black for a few seconds.
enum DisplayReloader {
    enum Failure: LocalizedError {
        case unavailable
        case noOtherDisplay
        case failed(CGError)
        case didNotReturn

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "This version of macOS doesn't support reloading displays. Unplug and replug the monitor instead."
            case .noOtherDisplay:
                return "Reloading needs another screen to stay on. Open your Mac's lid, or unplug and replug the monitor instead."
            case .failed(let error):
                return "macOS refused to reload the display (error \(error.rawValue)). Unplug and replug the monitor instead."
            case .didNotReturn:
                return "The display didn't come back on by itself. Unplug and replug it."
            }
        }
    }

    private typealias ConfigureEnabled = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

    /// Private SkyLight function; there is no public way to disable a display.
    private static let configureEnabled: ConfigureEnabled? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSConfigureDisplayEnabled") else {
            return nil
        }
        return unsafeBitCast(symbol, to: ConfigureEnabled.self)
    }()

    /// Blocks for several seconds; call off the main thread.
    static func reload(_ displays: [CGDirectDisplayID]) throws {
        guard let configureEnabled else { throw Failure.unavailable }
        let others = activeDisplays().filter { !displays.contains($0) }
        guard !others.isEmpty else { throw Failure.noOtherDisplay }

        // Session scope: if anything goes wrong, logging out restores the displays.
        try configure(displays) { config, display in configureEnabled(config, display, false) }
        Thread.sleep(forTimeInterval: 2)
        try configure(displays) { config, display in configureEnabled(config, display, true) }

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if Set(displays).isSubset(of: activeDisplays()) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw Failure.didNotReturn
    }

    private static func configure(
        _ displays: [CGDirectDisplayID],
        _ change: (CGDisplayConfigRef?, CGDirectDisplayID) -> CGError
    ) throws {
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success else { throw Failure.failed(begin) }
        for display in displays {
            let error = change(config, display)
            guard error == .success else {
                CGCancelDisplayConfiguration(config)
                throw Failure.failed(error)
            }
        }
        let complete = CGCompleteDisplayConfiguration(config, .forSession)
        guard complete == .success else { throw Failure.failed(complete) }
    }

    private static func activeDisplays() -> Set<CGDirectDisplayID> {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return Set(ids.prefix(Int(count)))
    }
}
