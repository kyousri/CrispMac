import AppKit
import SwiftUI

/// "Keep this display setting?" with a countdown, shown on the display that changed.
/// Running out reverts, so an unreadable mode fixes itself.
@MainActor
final class RevertPrompt {
    nonisolated static let seconds = 10

    private let countdown = Countdown()
    private var panel: NSPanel?
    private var timer: Timer?
    private var onKeep: (() -> Void)?
    private var onRevert: (() -> Void)?

    func show(on display: CGDirectDisplayID, onKeep: @escaping () -> Void, onRevert: @escaping () -> Void) {
        self.onKeep = onKeep
        self.onRevert = onRevert
        countdown.remaining = Self.seconds

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        center(panel, on: display)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate()

        // Screen geometry settles a moment after a mode switch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self, weak panel] in
            guard let self, let panel, panel.isVisible else { return }
            self.center(panel, on: display)
        }
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        onKeep = nil
        onRevert = nil
        panel?.orderOut(nil)
    }

    private func tick() {
        countdown.remaining -= 1
        if countdown.remaining <= 0 { finish(keep: false) }
    }

    private func finish(keep: Bool) {
        let action = keep ? onKeep : onRevert
        dismiss()
        action?()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = NSHostingController(rootView: RevertPromptView(
            countdown: countdown,
            keep: { [weak self] in self?.finish(keep: true) },
            revert: { [weak self] in self?.finish(keep: false) }
        ))
        return panel
    }

    private func center(_ panel: NSPanel, on display: CGDirectDisplayID) {
        guard let screen = DisplayService.screen(for: display) ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
    }
}

private final class Countdown: ObservableObject {
    @Published var remaining = RevertPrompt.seconds
}

private struct RevertPromptView: View {
    @ObservedObject var countdown: Countdown
    let keep: () -> Void
    let revert: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "display")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Keep this display setting?")
                .font(.headline)
            Text("Reverting in \(countdown.remaining) s")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Revert", action: revert)
                    .keyboardShortcut(.cancelAction)
                Button("Keep", action: keep)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 300)
    }
}
