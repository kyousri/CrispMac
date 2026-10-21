import Foundation

/// The size the desktop "looks like", in points.
public struct DisplaySize: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static func < (lhs: DisplaySize, rhs: DisplaySize) -> Bool {
        (lhs.width, lhs.height) < (rhs.width, rhs.height)
    }

    public var description: String { "\(width) × \(height)" }
}

/// A display mode as reported by the system, stripped of CoreGraphics types so it can be tested.
public struct ModeDescriptor: Hashable, Sendable {
    public let id: Int32
    public let width: Int
    public let height: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let refreshRate: Double
    public let isNative: Bool
    public let isDefault: Bool

    public init(
        id: Int32,
        width: Int,
        height: Int,
        pixelWidth: Int,
        pixelHeight: Int,
        refreshRate: Double,
        isNative: Bool = false,
        isDefault: Bool = false
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshRate = refreshRate
        self.isNative = isNative
        self.isDefault = isDefault
    }

    public var size: DisplaySize { DisplaySize(width: width, height: height) }

    /// Rendered at more pixels than it looks like, then scaled down to the panel.
    public var isHiDPI: Bool { pixelWidth > width }
}

/// What the user asked for on one display.
///
/// `hiDPI` is the user's wish, not the mode's state: it stays `true` at sizes that
/// have no sharp version so HiDPI comes back when they return to a size that does.
public struct DisplaySetting: Hashable, Codable, Sendable {
    public var size: DisplaySize
    public var hiDPI: Bool
    public var refreshRate: Double

    public init(size: DisplaySize, hiDPI: Bool, refreshRate: Double) {
        self.size = size
        self.hiDPI = hiDPI
        self.refreshRate = refreshRate
    }
}

public enum RefreshRate {
    public static func matches(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 0.01
    }

    public static func format(_ rate: Double) -> String {
        if abs(rate - rate.rounded()) < 0.01 {
            return "\(Int(rate.rounded())) Hz"
        }
        return String(format: "%.2f Hz", rate)
    }
}

public func describeMode(size: DisplaySize, hiDPI: Bool, refreshRate: Double) -> String {
    "\(size)\(hiDPI ? " HiDPI" : "") @ \(RefreshRate.format(refreshRate))"
}
