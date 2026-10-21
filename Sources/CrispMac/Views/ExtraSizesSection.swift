import CrispCore
import SwiftUI

/// Install, remove or reload the override that adds sharp sizes for a monitor model.
struct ExtraSizesSection: View {
    let state: DisplayState
    @ObservedObject var controller: DisplayController

    private var sizes: [DisplaySize] { DisplayOverride.sizes(native: state.display.catalog.nativeSize) }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if state.extraSizesInstalled {
                    Text("Installed: extra sizes from \(sizes.first?.description ?? "") to \(sizes.last?.description ?? ""), for every \(state.display.name).")
                        .fixedSize(horizontal: false, vertical: true)
                    if state.extraSizesMissing {
                        Label("macOS hasn't loaded them. Reload to bring them back.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Button("Remove Extra Sizes") { controller.removeExtraSizes(on: state.id) }
                        Spacer()
                        Button("Reload Sizes") { controller.reloadExtraSizes(on: state.id) }
                    }
                } else {
                    Text("macOS only offers a few sharp sizes for this monitor. Add \(sizes.count) sizes from \(sizes.first?.description ?? "") to \(sizes.last?.description ?? "").")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Asks for your password once. Your external displays go black for a few seconds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Add More Sharp Sizes") { controller.addExtraSizes(on: state.id) }
                        .buttonStyle(.borderedProminent)
                }
                if let busy = controller.busyMessage {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(busy).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(controller.busyMessage != nil)
        } label: {
            Text("Extra sharp sizes")
        }
    }
}
