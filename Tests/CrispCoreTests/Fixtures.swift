@testable import CrispCore

/// A trimmed copy of what an ASUS VG27AQ3A (2560×1440, 144 Hz) reports on an M1 Max.
enum ASUS {
    static let modes: [ModeDescriptor] = {
        var modes: [ModeDescriptor] = []
        var id: Int32 = 1
        func add(_ w: Int, _ h: Int, scale: Int, rates: [Double], native: Bool = false) {
            for rate in rates {
                modes.append(ModeDescriptor(
                    id: id, width: w, height: h,
                    pixelWidth: w * scale, pixelHeight: h * scale,
                    refreshRate: rate,
                    isNative: native,
                    isDefault: native && rate == 144
                ))
                id += 1
            }
        }
        let common: [Double] = [144, 120, 100, 60]
        add(2560, 1440, scale: 1, rates: common, native: true)
        add(2048, 1152, scale: 2, rates: [144])
        add(2048, 1152, scale: 1, rates: common)
        add(1920, 1080, scale: 1, rates: common + [50])
        add(1600, 1200, scale: 1, rates: common)
        add(1600, 900, scale: 1, rates: common)
        add(1680, 1050, scale: 1, rates: [60])
        add(1344, 756, scale: 1, rates: common)
        add(1280, 720, scale: 2, rates: common)
        add(1280, 720, scale: 1, rates: common + [50])
        add(1024, 576, scale: 2, rates: common)
        add(800, 600, scale: 2, rates: common)
        return modes
    }()

    static let catalog = ModeCatalog(modes: modes)
}

func size(_ w: Int, _ h: Int) -> DisplaySize { DisplaySize(width: w, height: h) }
