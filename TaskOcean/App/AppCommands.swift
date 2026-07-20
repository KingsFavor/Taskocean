import SwiftUI

/// App-level menu commands and their keyboard shortcuts (PRD FR-DAY-2, §8.3c ⌘R).
struct AppCommands: Commands {
    let store: AppStore

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button { store.goToPreviousDay() } label: { Text("cmd.previousDay") }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
            Button { store.goToNextDay() } label: { Text("cmd.nextDay") }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
            Button { store.goToToday() } label: { Text("cmd.goToToday") }
                .keyboardShortcut("t", modifiers: [.command])
            Divider()
            Button { Task { await store.refresh() } } label: { Text("cmd.refresh") }
                .keyboardShortcut("r", modifiers: [.command])
            Button { store.searchActive = true } label: { Text("cmd.search") }
                .keyboardShortcut("f", modifiers: [.command])
            Button { store.clearAllCompleted() } label: { Text("cmd.clearCompleted") }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            Divider()
            Button {
                store.alwaysOnTop.toggle()
            } label: { Text("cmd.alwaysOnTop") }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }
        // Replace the default "New Window" (a single-window utility) with New Task (⌘N).
        CommandGroup(replacing: .newItem) {
            Button { NotificationCenter.default.post(name: .editTask, object: "") } label: {
                Text("cmd.newTask")
            }
            .keyboardShortcut("n", modifiers: [.command])
        }
    }
}
