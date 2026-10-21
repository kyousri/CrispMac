import SwiftUI

/// The panel under the menu bar icon: quick controls for every external display.
struct MenuPanelView: View {
    @ObservedObject var controller: DisplayController
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if controller.displays.isEmpty {
                Text("No external display connected")
                    .foregroundStyle(.secondary)
            }
            ForEach(controller.displays) { state in
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.display.name)
                        .font(.headline)
                    DisplayControls(state: state, controller: controller)
                    if state.extraSizesMissing {
                        HStack {
                            Label("Extra sizes not loaded", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                            Button("Reload Sizes") { controller.reloadExtraSizes(on: state.id) }
                                .controlSize(.small)
                        }
                    }
                }
                Divider()
            }
            if let busy = controller.busyMessage {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(busy).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button("Open Settings…", action: openSettings)
                Spacer()
                Button("Quit CrispMac") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
