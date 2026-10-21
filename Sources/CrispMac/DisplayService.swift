import AppKit
import ColorSync
import CoreGraphics
import CrispCore

struct ExternalDisplay {
    let id: CGDirectDisplayID
    let key: String
    let name: String
    let catalog: ModeCatalog
    var currentMode: ModeDescriptor?
}

/// The only place that talks to CoreGraphics. Uses public APIs only.
enum DisplayService {
    private static let nativeFlag: UInt32 = 0x0200_0000 // kDisplayModeNativeFlag
    private static let defaultFlag: UInt32 = 0x0000_0004 // kDisplayModeDefaultFlag

    /// Connected external displays, skipping the built-in screen and mirrored copies.
    static func externalDisplays() -> [ExternalDisplay] {
        let ids = onlineDisplays().filter {
            CGDisplayIsBuiltin($0) == 0 && CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay
        }
        let keys = DisplayKey.keys(for: ids.map(identity))
        return zip(ids, keys).map { id, key in
            ExternalDisplay(
                id: id,
                key: key,
                name: name(of: id),
                catalog: ModeCatalog(modes: usableModes(of: id).map(descriptor)),
                currentMode: CGDisplayCopyDisplayMode(id).map(descriptor)
            )
        }
    }

    @discardableResult
    static func apply(_ mode: ModeDescriptor, to display: CGDirectDisplayID) -> Bool {
        guard let cgMode = usableModes(of: display).first(where: { $0.ioDisplayModeID == mode.id }) else {
            return false
        }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        guard CGConfigureDisplayWithDisplayMode(config, display, cgMode, nil) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }

    static func screen(for display: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
        }
    }

    private static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    private static func usableModes(of display: CGDirectDisplayID) -> [CGDisplayMode] {
        // Without this option macOS hides the normal-mode twins of HiDPI sizes.
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] ?? []
        return modes.filter { $0.isUsableForDesktopGUI() }
    }

    private static func descriptor(_ mode: CGDisplayMode) -> ModeDescriptor {
        ModeDescriptor(
            id: mode.ioDisplayModeID,
            width: mode.width,
            height: mode.height,
            pixelWidth: mode.pixelWidth,
            pixelHeight: mode.pixelHeight,
            refreshRate: mode.refreshRate,
            isNative: mode.ioFlags & nativeFlag != 0,
            isDefault: mode.ioFlags & defaultFlag != 0
        )
    }

    private static func identity(_ display: CGDirectDisplayID) -> DisplayIdentity {
        let uuid = CGDisplayCreateUUIDFromDisplayID(display)
            .map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
        return DisplayIdentity(
            uuid: uuid,
            vendor: CGDisplayVendorNumber(display),
            model: CGDisplayModelNumber(display),
            serial: CGDisplaySerialNumber(display),
            unit: CGDisplayUnitNumber(display)
        )
    }

    private static func name(of display: CGDirectDisplayID) -> String {
        screen(for: display)?.localizedName ?? "Display \(display)"
    }
}
