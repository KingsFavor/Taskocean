import SwiftUI

@main
struct TaskOceanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Real backend once the OAuth client ID is configured; mock otherwise.
    /// `TASKOCEAN_FORCE_MOCK=1` keeps the mock even when configured (UI dev).
    @State private var store = AppStore(repository: Self.makeRepository())

    /// Quiet "new version available" check (Homebrew/Developer ID build).
    @State private var updates = UpdateChecker()

    private static func makeRepository() -> TaskRepository {
        let forceMock = ProcessInfo.processInfo.environment["TASKOCEAN_FORCE_MOCK"] == "1"
        if GoogleOAuthConfig.isConfigured && !forceMock {
            return GoogleTasksRepository()
        }
        return MockTaskRepository()
    }

    var body: some Scene {
        // A single unique window (not WindowGroup): the Dock icon, the menu-bar
        // "open", and `openWindow` all focus this one window instead of spawning
        // duplicates. Reopen-when-hidden is handled by AppDelegate.
        Window("TaskOcean", id: MainWindow.id) {
            RootView()
                .environment(store)
                .environment(updates)
                .background(WindowConfigurator(store: store))
                .preferredLanguage(store.language)
                .task {
                    AppServices.shared.start(store: store)
                    updates.checkOnLaunch()
                }
        }
        .windowStyle(.hiddenTitleBar)
        // Content sets the *minimum* size (so a mode can't be crushed below its
        // legible floor) but the window is freely user-resizable; content fills
        // the frame and scrolls when it overflows. Mode switches snap to a sensible
        // default size (WindowConfigurator), after which the drag size is the user's.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 460, height: 640)
        .commands { AppCommands(store: store, updates: updates) }

        // Menu bar presence (PRD FR-4.3). Popover shows today's tasks.
        MenuBarExtra {
            MenuBarContent()
                .environment(store)
                .environment(updates)
                .preferredLanguage(store.language)
                .id(store.language)   // rebuild on language switch (imperative strings/dates)
        } label: {
            Image(systemName: "fish")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
                .environment(updates)
                .preferredLanguage(store.language)
        }
    }
}

/// Applies the manual-language override by overriding the SwiftUI locale.
private struct PreferredLanguageModifier: ViewModifier {
    let language: LanguageOption
    func body(content: Content) -> some View {
        switch language {
        case .system:  content
        case .korean:  content.environment(\.locale, Locale(identifier: "ko"))
        case .english: content.environment(\.locale, Locale(identifier: "en"))
        }
    }
}

extension View {
    func preferredLanguage(_ language: LanguageOption) -> some View {
        modifier(PreferredLanguageModifier(language: language))
    }
}

/// Handles the Dock-icon reopen so a click brings the existing window forward
/// (or unhides it) instead of leaving the user without a window / opening a new one.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag { return true }                    // a window is already visible — default is fine
        // Unhide the existing window ourselves; if it truly no longer exists,
        // let AppKit reopen the single `Window` scene.
        return !AppServices.showMainWindow()
    }
}
