import Foundation

/// The outcome of turning a `DisplaySetting` into a concrete mode.
public struct Resolution: Equatable, Sendable {
    public let mode: ModeDescriptor
    /// The setting actually in effect. `hiDPI` keeps the user's wish.
    public let setting: DisplaySetting
    /// True when the requested size or refresh rate was unavailable and a substitute was picked.
    public let isFallback: Bool
}

/// All the decisions about which sizes, sharp versions and refresh rates a display offers.
public struct ModeCatalog: Sendable {
    public let modes: [ModeDescriptor]
    public let nativeSize: DisplaySize
    /// Slider stops: every available size with the panel's aspect ratio, smallest first.
    public let sizes: [DisplaySize]

    private let sharpSizes: Set<DisplaySize>

    public init(modes: [ModeDescriptor]) {
        self.modes = modes

        let normal = modes.filter { !$0.isHiDPI }
        let native = normal.filter(\.isNative).max { $0.size < $1.size }
            ?? normal.max { $0.size < $1.size }
            ?? modes.max { $0.size < $1.size }
        nativeSize = native?.size ?? DisplaySize(width: 0, height: 0)

        let allSizes = Set(modes.map(\.size))
        let matchingAspect: Set<DisplaySize>
        if nativeSize.height > 0 {
            let aspect = Double(nativeSize.width) / Double(nativeSize.height)
            matchingAspect = allSizes.filter {
                abs(Double($0.width) / Double($0.height) - aspect) < 0.02
            }
        } else {
            matchingAspect = []
        }
        sizes = (matchingAspect.isEmpty ? allSizes : matchingAspect).sorted()
        sharpSizes = Set(modes.filter(\.isHiDPI).map(\.size))
    }

    public func hasSharpVersion(_ size: DisplaySize) -> Bool {
        sharpSizes.contains(size)
    }

    /// Distinct refresh rates for a size, highest first.
    public func refreshRates(for size: DisplaySize, hiDPI: Bool) -> [Double] {
        var rates: [Double] = []
        for mode in modes where mode.size == size && mode.isHiDPI == hiDPI {
            if !rates.contains(where: { RefreshRate.matches($0, mode.refreshRate) }) {
                rates.append(mode.refreshRate)
            }
        }
        return rates.sorted(by: >)
    }

    public func mode(size: DisplaySize, hiDPI: Bool, refreshRate: Double) -> ModeDescriptor? {
        modes
            .filter {
                $0.size == size && $0.isHiDPI == hiDPI && RefreshRate.matches($0.refreshRate, refreshRate)
            }
            .min { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.id < rhs.id
            }
    }

    /// The slider stop closest to `size`, used to place the knob for sizes outside the slider.
    public func closestSize(to size: DisplaySize) -> DisplaySize? {
        closest(to: size, in: sizes)
    }

    /// Picks the mode for a setting. Unavailable sizes fall back to the closest size that
    /// keeps the HiDPI wish; unavailable rates fall back to the highest one.
    public func resolve(_ wanted: DisplaySetting) -> Resolution? {
        guard !sizes.isEmpty else { return nil }

        let size: DisplaySize
        if sizes.contains(wanted.size) {
            size = wanted.size
        } else {
            let sharp = sizes.filter(hasSharpVersion)
            let pool = wanted.hiDPI && !sharp.isEmpty ? sharp : sizes
            guard let nearest = closest(to: wanted.size, in: pool) else { return nil }
            size = nearest
        }

        let hiDPI = wanted.hiDPI && hasSharpVersion(size)
        let rates = refreshRates(for: size, hiDPI: hiDPI)
        guard
            let rate = rates.first(where: { RefreshRate.matches($0, wanted.refreshRate) }) ?? rates.first,
            let mode = mode(size: size, hiDPI: hiDPI, refreshRate: rate)
        else { return nil }

        return Resolution(
            mode: mode,
            setting: DisplaySetting(size: size, hiDPI: wanted.hiDPI, refreshRate: rate),
            isFallback: size != wanted.size || !RefreshRate.matches(rate, wanted.refreshRate)
        )
    }

    /// The setting that describes a mode the display is already in.
    public func setting(for mode: ModeDescriptor) -> DisplaySetting {
        DisplaySetting(size: mode.size, hiDPI: mode.isHiDPI, refreshRate: mode.refreshRate)
    }

    /// Native size, HiDPI off, highest refresh rate: the emergency reset.
    public var nativeSetting: DisplaySetting? {
        guard let rate = refreshRates(for: nativeSize, hiDPI: false).first else { return nil }
        return DisplaySetting(size: nativeSize, hiDPI: false, refreshRate: rate)
    }

    private func closest(to size: DisplaySize, in pool: [DisplaySize]) -> DisplaySize? {
        pool.min { lhs, rhs in
            let l = abs(lhs.width - size.width)
            let r = abs(rhs.width - size.width)
            return l != r ? l < r : lhs.width > rhs.width
        }
    }
}
