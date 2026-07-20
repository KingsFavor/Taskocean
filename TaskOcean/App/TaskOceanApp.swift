import SwiftUI

@main
struct TaskOceanApp: App {
    /// Real backend once the OAuth client ID is configured; mock otherwise.
    /// `TASKOCEAN_FORCE_MOCK=1` keeps the mock even when configured (UI dev).
    @State private var store = AppStore(repository: Self.makeRepository())

    private static func makeRepository() -> TaskRepository {
        let forceMock = ProcessInfo.processInfo.environment["TASKOCEAN_FORCE_MOCK"] == "1"
        if GoogleOAuthConfig.isConfigured && !forceMock {
            return GoogleTasksRepository()
        }
        return MockTaskRepository()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(store)
                .background(WindowConfigurator(store: store))
                .preferredLanguage(store.language)
                .task { AppServices.shared.start(store: store) }
        }
        .windowStyle(.hiddenTitleBar)
        // Content sets the *minimum* size (so a mode can't be crushed below its
        // legible floor) but the window is freely user-resizable; content fills
        // the frame and scrolls when it overflows. Mode switches snap to a sensible
        // default size (WindowConfigurator), after which the drag size is the user's.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 460, height: 640)
        .commands { AppCommands(store: store) }

        // Menu bar presence (PRD FR-4.3). Popover shows today's tasks.
        MenuBarExtra {
            MenuBarContent()
                .environment(store)
                .preferredLanguage(store.language)
                .id(store.language)   // rebuild on language switch (imperative strings/dates)
        } label: {
            Image(systemName: "fish")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
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
