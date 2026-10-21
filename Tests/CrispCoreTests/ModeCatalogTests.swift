import Testing
@testable import CrispCore

@Suite struct SliderStops {
    let catalog = ASUS.catalog

    @Test func nativeSizeIsThePanelResolution() {
        #expect(catalog.nativeSize == size(2560, 1440))
    }

    @Test func stopsArePanelAspectRatioSizesFromHalfTheNativeWidth() {
        #expect(catalog.sizes == [
            size(1280, 720), size(1344, 756), size(1600, 900),
            size(1920, 1080), size(2048, 1152), size(2560, 1440),
        ])
    }

    @Test func sharpSizesAreTheOnesWithAHiDPIMode() {
        let sharp = catalog.sizes.filter(catalog.hasSharpVersion)
        #expect(sharp == [size(1280, 720), size(2048, 1152)])
    }

    @Test func hiDPICanOnlyBeToggledWhereBothVersionsExist() {
        #expect(catalog.canToggleHiDPI(size(2048, 1152)))
        #expect(!catalog.canToggleHiDPI(size(1920, 1080)))

        let sharpOnly = ModeCatalog(modes: [
            ModeDescriptor(id: 1, width: 2560, height: 1440, pixelWidth: 2560, pixelHeight: 1440, refreshRate: 144, isNative: true),
            ModeDescriptor(id: 2, width: 2304, height: 1296, pixelWidth: 4608, pixelHeight: 2592, refreshRate: 144),
        ])
        #expect(!sharpOnly.canToggleHiDPI(size(2304, 1296)))
    }

    @Test func ratesAreDistinctAndHighestFirst() {
        #expect(catalog.refreshRates(for: size(1920, 1080), hiDPI: false) == [144, 120, 100, 60, 50])
        #expect(catalog.refreshRates(for: size(2048, 1152), hiDPI: true) == [144])
        #expect(catalog.refreshRates(for: size(2560, 1440), hiDPI: true) == [])
    }

    @Test func duplicateModesPreferTheDefaultOne() {
        let modes = [
            ModeDescriptor(id: 9, width: 100, height: 50, pixelWidth: 100, pixelHeight: 50, refreshRate: 60),
            ModeDescriptor(id: 4, width: 100, height: 50, pixelWidth: 100, pixelHeight: 50, refreshRate: 60, isDefault: true),
            ModeDescriptor(id: 2, width: 100, height: 50, pixelWidth: 100, pixelHeight: 50, refreshRate: 60),
        ]
        #expect(ModeCatalog(modes: modes).mode(size: size(100, 50), hiDPI: false, refreshRate: 60)?.id == 4)
    }
}

@Suite struct Resolving {
    let catalog = ASUS.catalog

    @Test func exactSettingResolvesWithoutFallback() throws {
        let wanted = DisplaySetting(size: size(2048, 1152), hiDPI: true, refreshRate: 144)
        let result = try #require(catalog.resolve(wanted))
        #expect(result.mode.isHiDPI)
        #expect(result.mode.pixelWidth == 4096)
        #expect(result.setting == wanted)
        #expect(!result.isFallback)
    }

    @Test func hiDPIWishAtASizeWithoutSharpVersionUsesNormalModeAndKeepsTheWish() throws {
        let wanted = DisplaySetting(size: size(1920, 1080), hiDPI: true, refreshRate: 144)
        let result = try #require(catalog.resolve(wanted))
        #expect(!result.mode.isHiDPI)
        #expect(result.setting.hiDPI)
        #expect(!result.isFallback)
    }

    @Test func hiDPIOffAtASizeThatOnlyExistsSharpStaysSharp() throws {
        let sharpOnly = ModeCatalog(modes: [
            ModeDescriptor(id: 1, width: 2560, height: 1440, pixelWidth: 2560, pixelHeight: 1440, refreshRate: 144, isNative: true),
            ModeDescriptor(id: 2, width: 2304, height: 1296, pixelWidth: 4608, pixelHeight: 2592, refreshRate: 144),
        ])
        let wanted = DisplaySetting(size: size(2304, 1296), hiDPI: false, refreshRate: 144)
        let result = try #require(sharpOnly.resolve(wanted))
        #expect(result.mode.isHiDPI)
        #expect(!result.isFallback)
    }

    @Test func keepsTheRateWhenTheNewSizeHasIt() throws {
        let wanted = DisplaySetting(size: size(1600, 900), hiDPI: false, refreshRate: 100)
        #expect(try #require(catalog.resolve(wanted)).mode.refreshRate == 100)
    }

    @Test func picksTheHighestRateWhenTheWantedOneIsMissing() throws {
        // 2048×1152 HiDPI only exists at 144 Hz.
        let wanted = DisplaySetting(size: size(2048, 1152), hiDPI: true, refreshRate: 60)
        let result = try #require(catalog.resolve(wanted))
        #expect(result.mode.refreshRate == 144)
        #expect(result.isFallback)
    }

    @Test func missingSizeFallsBackToTheClosestSharpSizeWhenHiDPIIsWanted() throws {
        let wanted = DisplaySetting(size: size(2304, 1296), hiDPI: true, refreshRate: 144)
        let result = try #require(catalog.resolve(wanted))
        #expect(result.setting.size == size(2048, 1152))
        #expect(result.mode.isHiDPI)
        #expect(result.isFallback)
    }

    @Test func missingSizeFallsBackToTheClosestSizeWhenHiDPIIsOff() throws {
        let wanted = DisplaySetting(size: size(1856, 1044), hiDPI: false, refreshRate: 144)
        let result = try #require(catalog.resolve(wanted))
        #expect(result.setting.size == size(1920, 1080))
        #expect(result.isFallback)
    }

    @Test func closestSizeTieGoesToTheLargerSize() {
        let catalog = ModeCatalog(modes: [
            ModeDescriptor(id: 1, width: 1600, height: 900, pixelWidth: 1600, pixelHeight: 900, refreshRate: 60),
            ModeDescriptor(id: 2, width: 2000, height: 1125, pixelWidth: 2000, pixelHeight: 1125, refreshRate: 60, isNative: true),
        ])
        #expect(catalog.closestSize(to: size(1800, 1013)) == size(2000, 1125))
    }

    @Test func nativeResetIsNativeSizeNormalModeHighestRate() {
        #expect(catalog.nativeSetting == DisplaySetting(size: size(2560, 1440), hiDPI: false, refreshRate: 144))
    }

    @Test func emptyCatalogResolvesToNothing() {
        let wanted = DisplaySetting(size: size(2048, 1152), hiDPI: true, refreshRate: 144)
        #expect(ModeCatalog(modes: []).resolve(wanted) == nil)
    }
}
