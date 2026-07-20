import AppKit
import SwiftUI

/// Hosts the quick-capture UI in a floating borderless panel that can appear
/// over any app (like Spotlight). Toggled by the global hotkey.
@MainActor
final class QuickCaptureController {
    private var panel: NSPanel?
    private let store: AppStore

    init(store: AppStore) { self.store = store }

    func toggle() {
        if panel?.isVisible == true { close() } else { show() }
    }

    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        centerNearTop(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 110),
                            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = true

        let root = QuickCaptureView(onClose: { [weak self] in self?.close() })
            .environment(store)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    private func centerNearTop(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.midY + screen.frame.height * 0.18
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
