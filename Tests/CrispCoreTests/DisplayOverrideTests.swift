import Testing
@testable import CrispCore

@Suite struct OverrideFile {
    @Test func pathUsesLowercaseHexIDs() {
        #expect(DisplayOverride.path(vendor: 1715, model: 10223)
            == "/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-6b3/DisplayProductID-27ef")
    }

    @Test func addsTwentyOneSizesFor1440p() {
        let sizes = DisplayOverride.sizes(native: size(2560, 1440))
        #expect(sizes.count == 21)
        #expect(sizes.first == size(1280, 720))
        #expect(sizes.contains(size(2048, 1152)))
        #expect(sizes.contains(size(2304, 1296)))
        #expect(sizes.last == size(2560, 1440))
    }

    @Test func heightsFollowOtherAspectRatiosAndStayEven() {
        let sizes = DisplayOverride.sizes(native: size(3440, 1440))
        #expect(sizes.first == size(1720, 720))
        #expect(sizes.allSatisfy { $0.height % 2 == 0 })
    }

    @Test func entriesUseApplesTwelveByteFormat() {
        // 2048×1152 sharp is drawn at 4096×2304 (0x1000 × 0x900), flag 1.
        #expect(DisplayOverride.entry(for: size(2048, 1152), hiDPI: true)
            == [0, 0, 0x10, 0, 0, 0, 0x09, 0, 0, 0, 0, 1])
        #expect(DisplayOverride.entry(for: size(2048, 1152), hiDPI: false)
            == [0, 0, 0x08, 0, 0, 0, 0x04, 0x80, 0, 0, 0, 0])
    }

    @Test func contentsCarryTheMarkerAndBothVersionsOfEverySize() {
        let contents = DisplayOverride.contents(vendor: 1715, model: 10223, name: "VG27AQ3A", native: size(2560, 1440))
        #expect(contents[DisplayOverride.marker] as? Bool == true)
        #expect(contents["DisplayVendorID"] as? Int == 1715)
        #expect((contents["scale-resolutions"] as? [Any])?.count == 42)
    }
}

@Suite struct OverrideLoaded {
    static func catalog(sharpWidths: [Int]) -> ModeCatalog {
        var modes = [ModeDescriptor(id: 0, width: 2560, height: 1440, pixelWidth: 2560, pixelHeight: 1440, refreshRate: 144, isNative: true)]
        for (index, width) in sharpWidths.enumerated() {
            let height = width * 9 / 16
            modes.append(ModeDescriptor(id: Int32(index + 1), width: width, height: height,
                                        pixelWidth: width * 2, pixelHeight: height * 2, refreshRate: 144))
        }
        return ModeCatalog(modes: modes)
    }

    @Test func loadedWhenTheExtraSizesAreThere() {
        #expect(DisplayOverride.isLoaded(in: Self.catalog(sharpWidths: Array(stride(from: 1280, to: 2560, by: 64)))))
    }

    @Test func forgottenWhenOnlyMacOSDefaultsAreThere() {
        #expect(!DisplayOverride.isLoaded(in: Self.catalog(sharpWidths: [1280, 2048])))
    }
}
