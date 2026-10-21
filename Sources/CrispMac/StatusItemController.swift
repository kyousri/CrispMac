import AppKit
import Combine
import SwiftUI

/// The menu bar icon and its panel.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?
    private var badgeSubscription: AnyCancellable?

    init(controller: DisplayController, openSettings: @escaping () -> Void) {
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(toggle)
        }
        // A warning badge when macOS forgot a monitor's extra sizes.
        badgeSubscription = controller.$displays
            .map { $0.contains(where: \.extraSizesMissing) }
            .removeDuplicates()
            .sink { [weak self] missing in
                self?.item.button?.image = NSImage(
                    systemSymbolName: missing ? "display.trianglebadge.exclamationmark" : "display",
                    accessibilityDescription: missing ? "CrispMac: extra sizes not loaded" : "CrispMac"
                )
            }

        // Closed by hand rather than `.transient`, so the revert prompt can take
        // clicks without closing the panel mid-adjustment.
        popover.behavior = .applicationDefined
        let hosting = NSHostingController(rootView: MenuPanelView(
            controller: controller,
            openSettings: { [weak self] in
                self?.close()
                openSettings()
            }
        ))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    @objc private func toggle() {
        if popover.isShown {
            close()
        } else if let button = item.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
            popover.contentViewController?.view.window?.makeKey()
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            }
        }
    }

    private func close() {
        popover.performClose(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }
}
