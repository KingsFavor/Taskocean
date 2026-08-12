import SwiftUI

/// Preferences window (⌘,). Groups window/behavior/shortcut/notification/account options.
struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("settings.general", systemImage: "gearshape") }
            WindowSettings().tabItem { Label("settings.window", systemImage: "macwindow") }
            ShortcutSettings().tabItem { Label("settings.shortcuts", systemImage: "keyboard") }
            NotificationSettings().tabItem { Label("settings.notifications", systemImage: "bell") }
            AccountsSettings().tabItem { Label("settings.accounts", systemImage: "person.2") }
        }
        .frame(width: 480, height: 360)
        .environment(store)
    }
}

private struct GeneralSettings: View {
    @Environment(AppStore.self) private var store
    @State private var launchAtLogin = true

    var body: some View {
        Form {
            Picker("settings.language", selection: Binding(
                get: { store.language }, set: { store.language = $0 })) {
                Text("settings.language.system").tag(LanguageOption.system)
                Text("settings.language.korean").tag(LanguageOption.korean)
                Text("settings.language.english").tag(LanguageOption.english)
            }
            Toggle("settings.launchAtLogin", isOn: $launchAtLogin)
            Toggle("settings.showCompleted", isOn: Binding(
                get: { store.showCompleted }, set: { store.showCompleted = $0 }))
            Toggle("settings.groupByList", isOn: Binding(
                get: { store.groupByList }, set: { store.groupByList = $0 }))
            UpdateSettings()
        }
        .formStyle(.grouped)
        .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.set(on) }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

/// Updates section: current version, auto-check toggle, manual check + status.
private struct UpdateSettings: View {
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        Section {
            LabeledContent("update.currentVersion") { Text(verbatim: updates.currentVersion) }
            Toggle("update.autoCheck", isOn: Binding(
                get: { updates.autoCheckEnabled }, set: { updates.autoCheckEnabled = $0 }))
            HStack {
                Button("update.checkNow") { updates.manualCheck() }
                    .disabled(updates.isChecking)
                if updates.isChecking { ProgressView().controlSize(.small) }
                Spacer()
                statusLabel
            }
            if case .available = updates.lastResult {
                Button("update.openRelease") { updates.openReleasePage() }
            }
        } header: {
            Text("update.section")
        } footer: {
            Text("update.footer")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch updates.lastResult {
        case .idle:
            EmptyView()
        case .upToDate:
            Text("update.upToDate").foregroundStyle(.secondary)
        case .available(let v):
            Text(verbatim: "\(AppLocale.string("update.available", "New version")) \(v)")
                .foregroundStyle(.secondary)
        case .failed:
            Text("update.checkFailed").foregroundStyle(.secondary)
        }
    }
}

private struct WindowSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Toggle("settings.alwaysOnTop", isOn: Binding(
                get: { store.alwaysOnTop }, set: { store.alwaysOnTop = $0 }))
            Toggle("settings.allSpaces", isOn: Binding(
                get: { store.showOnAllSpaces }, set: { store.showOnAllSpaces = $0 }))
            Toggle("settings.autoFade", isOn: Binding(
                get: { store.autoFadeEnabled }, set: { store.autoFadeEnabled = $0 }))
            VStack(alignment: .leading) {
                Text("settings.opacity")
                Slider(value: Binding(get: { store.windowOpacity }, set: { store.windowOpacity = $0 }),
                       in: 0.4...1.0)
            }
            Picker("settings.windowMode", selection: Binding(
                get: { store.windowMode }, set: { store.windowMode = $0 })) {
                Text("mode.mini").tag(WindowMode.mini)
                Text("mode.compact").tag(WindowMode.compact)
                Text("mode.full").tag(WindowMode.full)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutSettings: View {
    @State private var capture = HotKeyPreferences.capture
    @State private var toggle = HotKeyPreferences.toggleWindow

    var body: some View {
        Form {
            Section {
                Picker("shortcuts.quickCapture", selection: $capture) {
                    ForEach(HotKeyPreferences.Combo.allCases) { combo in
                        Text(combo.display).tag(combo)
                    }
                }
                Picker("shortcuts.toggleWindow", selection: $toggle) {
                    ForEach(HotKeyPreferences.Combo.allCases) { combo in
                        Text(combo.display).tag(combo)
                    }
                }
            } footer: {
                Text("shortcuts.footer")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: capture) { _, new in
            HotKeyPreferences.capture = new
            AppServices.shared.registerHotKeys()
        }
        .onChange(of: toggle) { _, new in
            HotKeyPreferences.toggleWindow = new
            AppServices.shared.registerHotKeys()
        }
    }
}

private struct NotificationSettings: View {
    @Environment(AppStore.self) private var store
    @State private var enabled = NotificationScheduler.isEnabled
    @State private var hour = NotificationScheduler.hour

    var body: some View {
        Form {
            Section {
                Toggle("notif.enable", isOn: $enabled)
                if enabled {
                    Picker("notif.time", selection: $hour) {
                        ForEach(6...22, id: \.self) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }
                }
            } footer: {
                Text("notif.footer")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: enabled) { _, on in
            NotificationScheduler.isEnabled = on
            if on {
                Task {
                    _ = await NotificationScheduler.shared.requestPermission()
                    NotificationScheduler.shared.reschedule(tasks: store.tasksSnapshot)
                }
            }
        }
        .onChange(of: hour) { _, h in
            NotificationScheduler.hour = h
            NotificationScheduler.shared.reschedule(tasks: store.tasksSnapshot)
        }
    }
}

private struct AccountsSettings: View {
    @Environment(AppStore.self) private var store
    @State private var pendingDisconnect: Account?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.accounts) { account in
                HStack {
                    AccountAvatar(account: account, size: 22)
                    VStack(alignment: .leading) {
                        Text(account.displayName).font(.system(size: 12.5, weight: .semibold))
                        Text(account.email).font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if account.sessionState == .needsReauth {
                        Button("reauth.signIn") { Task { await store.reauthenticate(account.id) } }
                    }
                    Button(role: .destructive) { pendingDisconnect = account } label: {
                        Text("settings.disconnect")
                    }
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            Button { Task { await store.addAccount() } } label: {
                Label("filter.addAccount", systemImage: "plus")
            }
            Spacer()
        }
        .padding(16)
        .provideTheme(.light)
        .confirmationDialog(
            Text("settings.disconnect.confirm"),
            isPresented: Binding(get: { pendingDisconnect != nil },
                                 set: { if !$0 { pendingDisconnect = nil } }),
            presenting: pendingDisconnect
        ) { account in
            Button(role: .destructive) { store.removeAccount(account.id) } label: {
                Text("settings.disconnect")
            }
            Button(role: .cancel) {} label: { Text("action.cancel") }
        } message: { _ in
            Text("settings.disconnect.message")
        }
    }
}
