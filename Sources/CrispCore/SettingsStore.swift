import Foundation

/// Where settings are persisted. `UserDefaults` in the app, a dictionary in tests.
public protocol SettingsStorage: AnyObject {
    func string(forKey key: String) -> String?
    func storeString(_ value: String, forKey key: String)
}

extension UserDefaults: SettingsStorage {
    public func storeString(_ value: String, forKey key: String) {
        set(value, forKey: key)
    }
}

/// Saved display settings, one per display key.
public final class SettingsStore {
    private let storage: SettingsStorage
    private let storageKey = "displaySettings"

    public init(storage: SettingsStorage = UserDefaults.standard) {
        self.storage = storage
    }

    public func setting(for displayKey: String) -> DisplaySetting? {
        load()[displayKey]
    }

    public func save(_ setting: DisplaySetting, for displayKey: String) {
        var all = load()
        all[displayKey] = setting
        guard
            let data = try? JSONEncoder().encode(all),
            let json = String(data: data, encoding: .utf8)
        else { return }
        storage.storeString(json, forKey: storageKey)
    }

    private func load() -> [String: DisplaySetting] {
        guard
            let json = storage.string(forKey: storageKey),
            let all = try? JSONDecoder().decode([String: DisplaySetting].self, from: Data(json.utf8))
        else { return [:] }
        return all
    }
}
