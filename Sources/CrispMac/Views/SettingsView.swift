import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: DisplayController

    @State private var selectedKey: String?
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginMessage: String?

    private var selected: DisplayState? {
        controller.displays.first { $0.id == selectedKey } ?? controller.displays.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let selected {
                Picker("Display", selection: Binding(
                    get: { selected.id },
                    set: { selectedKey = $0 }
                )) {
                    ForEach(controller.displays) { state in
                        Text(state.display.name).tag(state.id)
                    }
                }
                GroupBox {
                    DisplayControls(state: selected, controller: controller, showsLegend: true)
                        .padding(8)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No external display connected")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: setLaunchAtLogin
                ))
                if let loginMessage {
                    Text(loginMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Press ⌃⌥⌘0 to reset every external display to its native resolution.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
        .onAppear(perform: refreshLoginState)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            loginMessage = "Couldn't change launch at login: \(error.localizedDescription)"
        }
        refreshLoginState()
    }

    private func refreshLoginState() {
        launchAtLogin = LoginItem.isEnabled
        if LoginItem.needsApproval {
            loginMessage = "Approve CrispMac in System Settings → General → Login Items."
        }
    }
}
