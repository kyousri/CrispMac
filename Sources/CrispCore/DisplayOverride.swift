import Foundation

/// The display override file that adds extra sizes for one monitor model.
///
/// macOS reads `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<hex>/DisplayProductID-<hex>`
/// whenever the display connects. Its `scale-resolutions` entries become ordinary display modes.
public enum DisplayOverride {
    /// Key stamped into files CrispMac writes, so it never deletes another tool's override.
    public static let marker = "CrispMacOverride"

    public static let overridesDirectory = "/Library/Displays/Contents/Resources/Overrides"

    public static func directory(vendor: UInt32) -> String {
        "\(overridesDirectory)/DisplayVendorID-\(String(vendor, radix: 16))"
    }

    public static func path(vendor: UInt32, model: UInt32) -> String {
        "\(directory(vendor: vendor))/DisplayProductID-\(String(model, radix: 16))"
    }

    /// The looks-like sizes to add: the native aspect ratio, 64 pt apart in width,
    /// from half the native width up to native.
    public static func sizes(native: DisplaySize) -> [DisplaySize] {
        guard native.width >= 2, native.height >= 2 else { return [] }
        return stride(from: native.width / 2, through: native.width, by: 64).map { width in
            let height = Int((Double(width) * Double(native.height) / Double(native.width)).rounded())
            return DisplaySize(width: width, height: height - height % 2)
        }
    }

    /// One `scale-resolutions` entry in Apple's format: big-endian pixel width, pixel height, flags.
    /// Flag 1 makes a HiDPI mode drawn at those pixels; flag 0 a normal mode.
    public static func entry(for size: DisplaySize, hiDPI: Bool) -> [UInt8] {
        let scale = hiDPI ? 2 : 1
        return [UInt32(size.width * scale), UInt32(size.height * scale), hiDPI ? 1 : 0]
            .flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - $0 * 8)) } }
    }

    /// The override's contents, ready for `PropertyListSerialization`.
    public static func contents(vendor: UInt32, model: UInt32, name: String, native: DisplaySize) -> [String: Any] {
        let sizes = sizes(native: native)
        let entries = sizes.map { entry(for: $0, hiDPI: true) } + sizes.map { entry(for: $0, hiDPI: false) }
        return [
            "DisplayVendorID": Int(vendor),
            "DisplayProductID": Int(model),
            "DisplayProductName": name,
            "scale-resolutions": entries.map { Data($0) },
            marker: true,
        ]
    }

    /// Whether macOS has loaded an installed override. After sleep or a replug macOS
    /// sometimes comes back without the extra sizes; most of them missing means it forgot.
    /// The native size is skipped: macOS never offers it sharp.
    public static func isLoaded(in catalog: ModeCatalog) -> Bool {
        let expected = sizes(native: catalog.nativeSize).filter { $0 != catalog.nativeSize }
        guard !expected.isEmpty else { return true }
        let present = expected.filter(catalog.hasSharpVersion).count
        return present * 2 >= expected.count
    }
}
