import SwiftUI
import AppKit

/// Bridges SwiftUI to the host `NSWindow` for "always-on-top" floating (PRD
/// FR-1.1/1.6), opacity (FR-1.4), and position restore (FR-1.2).
///
/// This is a plain `View` (not the representable) on purpose: it *reads* the
/// observable window prefs in `body`, so toggling the pin re-evaluates it and
/// pushes fresh values into the bridge — otherwise `updateNSView` never fires
/// on an `alwaysOnTop` change and unpinning wouldn't drop the window level.
struct WindowConfigurator: View {
    var store: AppStore

    var body: some View {
        WindowConfigBridge(alwaysOnTop: store.alwaysOnTop,
                           showOnAllSpaces: store.showOnAllSpaces,
                           opacity: store.windowOpacity,
                           windowMode: store.windowMode)
    }
}

private struct WindowConfigBridge: NSViewRepresentable {
    var alwaysOnTop: Bool
    var showOnAllSpaces: Bool
    var opacity: Double
    var windowMode: WindowMode

    /// Tracks the last mode we sized the window for, so a plain re-render (pin
    /// toggle, opacity) is distinguished from a real mode switch.
    final class Coordinator { var appliedMode: WindowMode? }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = TrackerView()
        let coordinator = context.coordinator
        view.onResolve = { window in apply(to: window, view: view, coordinator: coordinator) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? TrackerView, let window = view.window else { return }
        apply(to: window, view: view, coordinator: context.coordinator)
    }

    /// Default frame size a mode falls back to the first time it's shown (nothing
    /// remembered yet). The window is hidden-titlebar, so frame ≈ content size.
    private func defaultSize(for mode: WindowMode) -> NSSize {
        switch mode {
        case .mini:    return NSSize(width: 340, height: 96)
        case .compact: return NSSize(width: 360, height: 400)
        case .full:    return NSSize(width: 460, height: 640)
        }
    }

    // MARK: Per-mode frame persistence (FR-1.2)
    //
    // Each mode remembers its own window frame so a manual resize sticks *per mode*
    // (a big 확장 window and a tiny 미니 strip coexist). We own this rather than the
    // SwiftUI window autosave, which keeps a single shared frame across modes — that
    // would reopen 확장 at the strip's size. SwiftUI autosave is disabled below.

    private static func frameKey(_ mode: WindowMode) -> String { "taskocean.windowFrame.\(mode.rawValue)" }

    static func storeFrame(_ frame: NSRect, mode: WindowMode) {
        UserDefaults.standard.set("\(frame.minX) \(frame.minY) \(frame.width) \(frame.height)",
                                  forKey: frameKey(mode))
    }

    private func loadFrame(_ mode: WindowMode) -> NSRect? {
        guard let s = UserDefaults.standard.string(forKey: Self.frameKey(mode)) else { return nil }
        let n = s.split(separator: " ").compactMap { Double($0) }
        guard n.count == 4, n[2] > 0, n[3] > 0 else { return nil }
        return NSRect(x: n[0], y: n[1], width: n[2], height: n[3])
    }

    private func applyModeSizing(_ window: NSWindow, _ view: TrackerView, _ coordinator: Coordinator) {
        let previous = coordinator.appliedMode
        coordinator.appliedMode = windowMode
        view.currentMode = windowMode      // so the resize/move observer files drags under the right mode
        guard previous != windowMode else { return }   // same mode: leave a drag in progress alone

        // First paint restores this mode's whole frame (position + size); a live
        // switch keeps the current top-left and applies the entered mode's size.
        // `isFirstPaint` also decides whether we restore position.
        let restoreFullFrame = previous == nil
        let saved = loadFrame(windowMode)
        let size = saved?.size ?? defaultSize(for: windowMode)

        // Apply *after* SwiftUI's own layout/sizing pass (which otherwise clobbers a
        // synchronous setFrame here), and suspend persistence so this programmatic
        // change isn't recorded as a user drag.
        DispatchQueue.main.async {
            view.suspendPersistence = true
            if restoreFullFrame, let frame = saved {
                window.setFrame(window.constrainFrameRect(frame, to: window.screen),
                                display: true, animate: false)
            } else {
                self.resize(window, toSize: size)
            }
            DispatchQueue.main.async { view.suspendPersistence = false }
        }
    }

    /// Resize the window while pinning its top-left corner in place.
    private func resize(_ window: NSWindow, toSize size: NSSize) {
        let top = window.frame.maxY, left = window.frame.minX
        window.setFrame(NSRect(x: left, y: top - size.height, width: size.width, height: size.height),
                        display: true, animate: false)
    }

    private func apply(to window: NSWindow, view: TrackerView, coordinator: Coordinator) {
        applyModeSizing(window, view, coordinator)

        // Floating level keeps us above normal windows but below full-screen apps.
        window.level = alwaysOnTop ? .floating : .normal

        var behavior: NSWindow.CollectionBehavior = [.managed]
        if showOnAllSpaces {
            behavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        window.collectionBehavior = behavior

        window.alphaValue = CGFloat(opacity)
        // Move via the top chrome (titlebar region) only. Background dragging
        // would otherwise hijack task drag-to-reorder. The top ~36px chrome row
        // sits over the transparent titlebar and stays draggable.
        window.isMovableByWindowBackground = false
        window.isMovable = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
    }

    /// Small NSView that resolves its window once attached and persists the current
    /// mode's frame whenever the user drags or resizes it.
    final class TrackerView: NSView {
        var onResolve: ((NSWindow) -> Void)?
        var currentMode: WindowMode = .full
        /// True while we're resizing the window ourselves, so the observer doesn't
        /// record a programmatic size change as if it were a user drag. Starts true
        /// so SwiftUI's initial sizing pass (before our first restore) isn't saved.
        var suspendPersistence = true
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onResolve?(window)
            let nc = NotificationCenter.default
            for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
                observers.append(nc.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    guard let self, !self.suspendPersistence, let window = self.window else { return }
                    WindowConfigBridge.storeFrame(window.frame, mode: self.currentMode)
                })
            }
        }

        deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
    }
}

/// An explicit "drag the window here" region. Place behind the top chrome so the
/// window moves when the chrome is dragged, while task cards (which return the
/// default `false`) stay free for drag-to-reorder.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggableNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DraggableNSView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}
