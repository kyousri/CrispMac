import AppKit
import CrispCore

struct DisplayState: Identifiable {
    var display: ExternalDisplay
    /// What the controls show. `hiDPI` is the user's wish (see `DisplaySetting`).
    var setting: DisplaySetting
    var note: String?

    var id: String { display.key }
}

/// Owns the connected displays, applies changes, and re-applies saved settings
/// at launch, on wake and whenever displays are reconfigured.
@MainActor
final class DisplayController: ObservableObject {
    @Published private(set) var displays: [DisplayState] = []

    /// A change shown on screen but not yet confirmed in the revert prompt.
    private struct PendingChange {
        let key: String
        let revertMode: ModeDescriptor?
        let revertSetting: DisplaySetting
    }

    private let store: SettingsStore
    private let prompt = RevertPrompt()
    private var pending: PendingChange?
    private var refreshWork: DispatchWorkItem?

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        CGDisplayRegisterReconfigurationCallback(Self.reconfigured, Unmanaged.passUnretained(self).toOpaque())
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh(after: 2) }
            }
        }
        refresh()
    }

    private static let reconfigured: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
        guard !flags.contains(.beginConfigurationFlag), let userInfo else { return }
        let controller = Unmanaged<DisplayController>.fromOpaque(userInfo).takeUnretainedValue()
        DispatchQueue.main.async {
            MainActor.assumeIsolated { controller.scheduleRefresh(after: 1) }
        }
    }

    // MARK: - User changes

    func setSize(_ size: DisplaySize, on key: String) {
        change(key) { $0.size = size }
    }

    func setHiDPI(_ hiDPI: Bool, on key: String) {
        change(key) { $0.hiDPI = hiDPI }
    }

    func setRefreshRate(_ rate: Double, on key: String) {
        change(key) { $0.refreshRate = rate }
    }

    private func change(_ key: String, _ edit: (inout DisplaySetting) -> Void) {
        guard let index = displays.firstIndex(where: { $0.id == key }) else { return }
        let state = displays[index]
        var wanted = state.setting
        edit(&wanted)
        guard wanted != state.setting, let resolution = state.display.catalog.resolve(wanted) else { return }

        if resolution.mode.id == state.display.currentMode?.id {
            // Only the HiDPI wish changed; nothing to switch or confirm.
            displays[index].setting = resolution.setting
            if pending?.key != key { store.save(resolution.setting, for: key) }
            return
        }

        if let pending, pending.key != key { keepPending() }
        let isFirstChange = pending == nil
        if isFirstChange {
            pending = PendingChange(key: key, revertMode: state.display.currentMode, revertSetting: state.setting)
        }

        guard DisplayService.apply(resolution.mode, to: state.display.id) else {
            if isFirstChange { pending = nil }
            displays[index].note = "Couldn't switch to \(describe(resolution))"
            return
        }
        displays[index].display.currentMode = resolution.mode
        displays[index].setting = resolution.setting
        displays[index].note = nil
        prompt.show(
            on: state.display.id,
            onKeep: { [weak self] in self?.keepPending() },
            onRevert: { [weak self] in self?.revertPending() }
        )
    }

    private func keepPending() {
        guard let change = pending else { return }
        pending = nil
        prompt.dismiss()
        if let state = displays.first(where: { $0.id == change.key }) {
            store.save(state.setting, for: change.key)
        }
    }

    func revertPending() {
        guard let change = pending else { return }
        pending = nil
        prompt.dismiss()
        guard let index = displays.firstIndex(where: { $0.id == change.key }) else { return }
        if let mode = change.revertMode, DisplayService.apply(mode, to: displays[index].display.id) {
            displays[index].display.currentMode = mode
        }
        displays[index].setting = change.revertSetting
    }

    /// The ⌃⌥⌘0 escape hatch: native size, HiDPI off, highest rate, on every external display.
    func resetAllToNative() {
        pending = nil
        prompt.dismiss()
        for index in displays.indices {
            let display = displays[index].display
            guard
                let native = display.catalog.nativeSetting,
                let resolution = display.catalog.resolve(native)
            else { continue }
            if DisplayService.apply(resolution.mode, to: display.id) {
                displays[index].display.currentMode = resolution.mode
            }
            displays[index].setting = resolution.setting
            displays[index].note = nil
            store.save(resolution.setting, for: display.key)
        }
    }

    // MARK: - Keeping displays in sync

    private func scheduleRefresh(after delay: TimeInterval) {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Re-reads the connected displays and re-applies saved settings where the mode drifted.
    func refresh() {
        let connected = DisplayService.externalDisplays()
        if let change = pending, !connected.contains(where: { $0.key == change.key }) {
            pending = nil
            prompt.dismiss()
        }
        displays = connected.compactMap { display in
            if let change = pending, change.key == display.key,
               let shown = displays.first(where: { $0.id == display.key }) {
                return DisplayState(display: display, setting: shown.setting, note: nil)
            }
            return reapplySaved(on: display)
        }
    }

    private func reapplySaved(on display: ExternalDisplay) -> DisplayState? {
        guard let current = display.currentMode else { return nil }
        guard
            let saved = store.setting(for: display.key),
            let resolution = display.catalog.resolve(saved)
        else {
            return DisplayState(display: display, setting: display.catalog.setting(for: current))
        }

        var display = display
        if current.id != resolution.mode.id {
            guard DisplayService.apply(resolution.mode, to: display.id) else {
                return DisplayState(
                    display: display,
                    setting: display.catalog.setting(for: current),
                    note: "Couldn't restore \(describe(resolution))"
                )
            }
            display.currentMode = resolution.mode
        }

        let note = resolution.isFallback
            ? "Saved \(describeMode(size: saved.size, hiDPI: saved.hiDPI, refreshRate: saved.refreshRate)) "
                + "unavailable, using \(describe(resolution))"
            : nil
        return DisplayState(display: display, setting: resolution.setting, note: note)
    }

    private func describe(_ resolution: Resolution) -> String {
        describeMode(
            size: resolution.mode.size,
            hiDPI: resolution.mode.isHiDPI,
            refreshRate: resolution.mode.refreshRate
        )
    }
}
