import SwiftUI

/// Menu-bar popover (design section 03). Shows today's tasks + quick add.
struct MenuBarContent: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content.provideTheme(colorScheme)
    }

    private var content: some View {
        MenuBarBody(openWindow: openWindow)
    }
}

private struct MenuBarBody: View {
    let openWindow: OpenWindowAction
    @Environment(AppStore.self) private var store
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.theme) private var theme
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Wordmark(logoHeight: 12, fontSize: 15)
                DevBadge()
                Spacer()
                Text("menubar.todayCount \(store.remainingTodayCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            Divider().overlay(theme.divider)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.dayContent.today) { node in
                        HStack(spacing: 9) {
                            Checkbox(isCompleted: node.task.isCompleted, size: 15) {
                                store.toggleComplete(node.task.id)
                            }
                            Text(node.task.title)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(node.task.isCompleted ? theme.textFaint : theme.textPrimary)
                                .strikethrough(node.task.isCompleted, color: theme.checkboxRing)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let account = store.account(node.task.accountID) {
                                AccountAvatar(account: account, size: 15)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    }
                }
            }
            .frame(maxHeight: 220)

            Divider().overlay(theme.divider)
            HStack(spacing: 8) {
                Image(systemName: "plus.circle").foregroundStyle(theme.iconMuted)
                TextField(text: $draft) { Text("menubar.quickAdd") }
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .onSubmit {
                        let t = draft.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { store.addTask(title: t, due: nil); draft = "" }
                    }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)

            // Quiet update row — appears only when a newer version is available
            // (mirrors the day-view banner for mini/compact users). Opens the release.
            if updates.isBannerVisible {
                Divider().overlay(theme.divider)
                Button {
                    updates.openReleasePage()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.syncOK)
                        Text("\(AppLocale.string("update.available", "New version")) \(updates.latestVersion ?? "") · \(AppLocale.string("update.action", "Update"))")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .help(Text(verbatim: UpdateChecker.brewUpdateCommand))
                .contextMenu {
                    Button("update.copyCommand") { updates.copyUpdateCommand() }
                    Button("update.openRelease") { updates.openReleasePage() }
                }
            }

            Divider().overlay(theme.divider)
            Button {
                openWindow(id: MainWindow.id)
                AppServices.showMainWindow()
            } label: {
                Text("menubar.openApp")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
        }
        .frame(width: 300)
        .background(theme.window)
    }
}
