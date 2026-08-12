import AppKit
import SwiftUI

/// One-time app-level services: global hotkeys, quick-capture panel, dock badge,
/// local notifications, auto-fade. Started from the main window's `.task`.
@MainActor
final class AppServices {
    static let shared = AppServices()
    private init() {}

    private var started = false
    private let relauncher = UpdateRelauncher()
    private var quickCapture: QuickCaptureController?
    private var captureHotKeyID: UInt32?
    private var toggleHotKeyID: UInt32?
    private weak var store: AppStore?
    private var fadeTimer: Timer?

    func start(store: AppStore) {
        guard !started else { return }
        started = true
        self.store = store

        // Dev-only overrides for visual testing (no effect unless set).
        if let forced = ProcessInfo.processInfo.environment["TASKOCEAN_APPEARANCE"] {
            NSApp.appearance = NSAppearance(named: forced == "dark" ? .darkAqua : .aqua)
        }
        if let mode = ProcessInfo.processInfo.environment["TASKOCEAN_MODE"]
            .flatMap(WindowMode.init(rawValue:)) {
            store.windowMode = mode
        }
        // Dev-only: force UI language for bilingual captures (en/ko).
        if let lang = ProcessInfo.processInfo.environment["TASKOCEAN_LANG"] {
            store.language = lang == "en" ? .english : .korean
        }

        quickCapture = QuickCaptureController(store: store)
        registerHotKeys()

        // Dock badge + notification replan on every data change (FR-4.2, FR-6.2).
        store.onDataChanged = { [weak self] in
            self?.updateDockBadge()
            self?.rescheduleNotifications()
        }
        updateDockBadge()
        rescheduleNotifications()
        startAutoFadeMonitor()
        relauncher.start()   // auto-relaunch into a Homebrew-installed update (distribution only)
    }

    // MARK: Hotkeys (FR-5.1/5.4/5.7)

    /// (Re)register the two global shortcuts from preferences.
    func registerHotKeys() {
        if let id = captureHotKeyID { HotKeyManager.shared.unregister(id) }
        if let id = toggleHotKeyID { HotKeyManager.shared.unregister(id) }

        let capture = HotKeyPreferences.capture
        captureHotKeyID = HotKeyManager.shared.register(
            keyCode: capture.keyCode, modifiers: capture.modifiers) { [weak self] in
            Task { @MainActor in self?.quickCapture?.toggle() }
        }

        let toggle = HotKeyPreferences.toggleWindow
        toggleHotKeyID = HotKeyManager.shared.register(
            keyCode: toggle.keyCode, modifiers: toggle.modifiers) {
            Task { @MainActor in Self.toggleMainWindow() }
        }
    }

    /// Show/hide the main window without tearing it down (FR-5.4).
    static func toggleMainWindow() {
        guard let window = mainWindow() else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if window.isVisible && NSApp.isActive {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// The single main window, by its stable identifier (survives the per-mode
    /// frame-autosave renaming from A77).
    static func mainWindow() -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == MainWindow.id }
    }

    /// Bring the existing main window forward (Dock reopen / menu "open") instead
    /// of spawning a new one. Returns true if it handled an existing window.
    @discardableResult
    static func showMainWindow() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = mainWindow() else { return false }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    // MARK: Dock badge (FR-4.2)

    private func updateDockBadge() {
        guard let store else { return }
        let remaining = store.remainingTodayCount
        NSApp.dockTile.badgeLabel = remaining > 0 ? String(remaining) : nil
    }

    // MARK: Notifications (FR-6.2)

    private var notifyTask: Task<Void, Never>?

    /// Debounced + async so it never blocks the UI on rapid complete/incomplete
    /// toggles — only the last change within the window actually re-plans.
    private func rescheduleNotifications() {
        notifyTask?.cancel()
        notifyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let store = self?.store else { return }
            NotificationScheduler.shared.reschedule(tasks: store.tasksSnapshot)
        }
    }

    // MARK: Auto-fade (FR-1.7)

    /// While enabled: if the pointer is outside the main window for a while,
    /// gently drop opacity; restore instantly when the pointer returns.
    private func startAutoFadeMonitor() {
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in AppServices.shared.tickAutoFade() }
        }
    }

    private func tickAutoFade() {
        guard let store, store.autoFadeEnabled else { return }
        guard let window = NSApp.windows.first(where: { $0.frameAutosaveName == "TaskOcean.main" }),
              window.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        let inside = window.frame.insetBy(dx: -8, dy: -8).contains(mouse)
        let target: CGFloat = inside ? CGFloat(store.windowOpacity)
                                     : CGFloat(store.windowOpacity) * 0.45
        if abs(window.alphaValue - target) > 0.01 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = inside ? 0.15 : 0.6
                window.animator().alphaValue = target
            }
        }
    }
}
