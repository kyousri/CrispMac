import CrispCore
import SwiftUI

/// HiDPI switch, resolution slider and refresh rate picker for one display.
/// Shared by the menu bar panel and the settings window.
struct DisplayControls: View {
    let state: DisplayState
    let controller: DisplayController
    var showsLegend = false

    /// Slider position while dragging; the change is applied on release.
    @State private var dragIndex: Double?

    private var catalog: ModeCatalog { state.display.catalog }
    private var sizes: [DisplaySize] { catalog.sizes }
    private var canToggleHiDPI: Bool { catalog.canToggleHiDPI(state.setting.size) }
    private var hiDPIActive: Bool { catalog.usesHiDPI(state.setting.size, wanted: state.setting.hiDPI) }

    private var settledIndex: Int {
        let stop = catalog.closestSize(to: state.setting.size) ?? state.setting.size
        return sizes.firstIndex(of: stop) ?? 0
    }

    private var shownSize: DisplaySize {
        guard let dragIndex else { return state.setting.size }
        return sizes[Int(dragIndex.rounded())]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hiDPIRow
            resolutionRow
            refreshRateRow
            if let note = state.note {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hiDPIRow: some View {
        HStack {
            Text("HiDPI")
            if !canToggleHiDPI {
                Text(hiDPIActive ? "Always on at this size" : "Not available at this size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("HiDPI", isOn: Binding(
                get: { hiDPIActive },
                set: { controller.setHiDPI($0, on: state.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(!canToggleHiDPI)
        }
    }

    private var resolutionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Resolution")
                Spacer()
                if catalog.hasSharpVersion(shownSize) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                        .help("Has a sharp HiDPI version")
                }
                Text(shownSize.description)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if sizes.count > 1 {
                slider
                sharpMarkers
                if showsLegend {
                    Text("Dots mark sizes that have a sharp HiDPI version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var slider: some View {
        Slider(
            value: Binding(
                get: { dragIndex ?? Double(settledIndex) },
                set: { dragIndex = $0 }
            ),
            in: 0...Double(sizes.count - 1),
            step: 1
        ) {
            Text("Resolution")
        } onEditingChanged: { editing in
            guard !editing, let index = dragIndex else { return }
            dragIndex = nil
            controller.setSize(sizes[Int(index.rounded())], on: state.id)
        }
        .labelsHidden()
    }

    /// Dots under the slider at the stops that have a sharp version.
    private var sharpMarkers: some View {
        GeometryReader { geometry in
            // The knob's centre never reaches the track ends; match its travel.
            let inset: CGFloat = 10
            let travel = geometry.size.width - inset * 2
            ForEach(sizes.indices.filter { catalog.hasSharpVersion(sizes[$0]) }, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
                    .position(
                        x: inset + travel * CGFloat(index) / CGFloat(sizes.count - 1),
                        y: 2.5
                    )
            }
        }
        .frame(height: 5)
    }

    private var refreshRateRow: some View {
        let rates = catalog.refreshRates(for: state.setting.size, hiDPI: hiDPIActive)
        let selected = rates.first { RefreshRate.matches($0, state.setting.refreshRate) }
            ?? state.setting.refreshRate
        return HStack {
            Text("Refresh rate")
            Spacer()
            Picker("Refresh rate", selection: Binding(
                get: { selected },
                set: { controller.setRefreshRate($0, on: state.id) }
            )) {
                ForEach(rates, id: \.self) { rate in
                    Text(RefreshRate.format(rate)).tag(rate)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }
}
