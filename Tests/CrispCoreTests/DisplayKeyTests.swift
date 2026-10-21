import Testing
@testable import CrispCore

@Suite struct DisplayKeys {
    @Test func usesTheSystemUUIDWhenThereIsOne() {
        let asus = DisplayIdentity(uuid: "FC916B84", vendor: 1715, model: 10223, serial: 16843009, unit: 2)
        #expect(DisplayKey.keys(for: [asus]) == ["FC916B84"])
    }

    @Test func fallsBackToVendorModelSerial() {
        let display = DisplayIdentity(uuid: nil, vendor: 1, model: 2, serial: 3, unit: 4)
        #expect(DisplayKey.keys(for: [display]) == ["1-2-3"])
    }

    @Test func identicalMonitorsAreToldApartByPort() {
        let left = DisplayIdentity(uuid: nil, vendor: 1, model: 2, serial: 0, unit: 1)
        let right = DisplayIdentity(uuid: nil, vendor: 1, model: 2, serial: 0, unit: 2)
        let other = DisplayIdentity(uuid: "ABC", vendor: 5, model: 6, serial: 7, unit: 3)
        #expect(DisplayKey.keys(for: [left, right, other]) == ["1-2-0-port1", "1-2-0-port2", "ABC"])
    }
}

@Suite struct SavedSettings {
    final class MemoryStorage: SettingsStorage {
        var values: [String: String] = [:]
        func string(forKey key: String) -> String? { values[key] }
        func storeString(_ value: String, forKey key: String) { values[key] = value }
    }

    @Test func roundTripsPerDisplay() {
        let store = SettingsStore(storage: MemoryStorage())
        let sharp = DisplaySetting(size: size(2048, 1152), hiDPI: true, refreshRate: 144)
        let plain = DisplaySetting(size: size(1920, 1080), hiDPI: false, refreshRate: 60)

        store.save(sharp, for: "a")
        store.save(plain, for: "b")

        #expect(store.setting(for: "a") == sharp)
        #expect(store.setting(for: "b") == plain)
        #expect(store.setting(for: "c") == nil)
    }
}
