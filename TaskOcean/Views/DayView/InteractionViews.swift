import SwiftUI

/// Right-click menu on a task (design section 06).
struct TaskContextMenu: View {
    let node: TaskNode
    @Environment(AppStore.self) private var store

    var body: some View {
        Button { NotificationCenter.default.post(name: .editTask, object: node.task.id) } label: {
            Label("menu.edit", systemImage: "pencil")
        }
        Button { store.toggleComplete(node.task.id) } label: {
            Label(node.task.isCompleted ? "menu.markIncomplete" : "menu.markComplete",
                  systemImage: "checkmark.circle")
        }
        .keyboardShortcut(.return, modifiers: .command)   // ⌘⏎ hint (design section 06)
        if isOverdue {
            Button { store.moveToToday(node.task.id) } label: {
                Label("overdue.moveToToday", systemImage: "arrow.uturn.forward")
            }
        }
        Divider()
        Menu {
            ForEach(store.lists.filter { $0.accountID == node.task.accountID && $0.id != node.task.listID }) { list in
                Button(list.title) { moveToList(list.id) }
            }
        } label: { Label("menu.moveList", systemImage: "arrow.right.circle") }
        Menu {
            ForEach(store.accounts.filter { $0.id != node.task.accountID }) { acc in
                Menu(acc.displayName) {
                    ForEach(store.lists.filter { $0.accountID == acc.id }) { list in
                        // Cross-account = recreate in target + delete original (§8.4.5).
                        Button(list.title) { store.moveTaskToAccount(node.task.id, targetListID: list.id) }
                    }
                }
            }
        } label: { Label("menu.moveAccount", systemImage: "person.2") }
        Button { duplicate() } label: { Label("menu.duplicate", systemImage: "plus.square.on.square") }
        Divider()
        Button(role: .destructive) { store.pendingDeleteTaskID = node.task.id } label: {
            Label("menu.delete", systemImage: "trash")
        }
    }

    /// Incomplete with a due date before today (same day-granularity as dayContent).
    private var isOverdue: Bool {
        guard !node.task.isCompleted, let due = node.task.due else { return false }
        return Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: Date())
    }

    private func moveToList(_ listID: String) {
        var t = node.task; t.listID = listID; store.updateTask(t)
    }
    private func duplicate() {
        store.addTask(title: node.task.title, listID: node.task.listID,
                      due: node.task.due, notes: node.task.notes)
    }
}

/// Account · list filter panel (design section 04).
struct FilterPanel: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("filter.accountsLists")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("filter.showingCount \(shownCount)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(.bottom, 10)

            ForEach(store.accounts) { account in
                accountSection(account)
            }

            Divider().overlay(theme.divider).padding(.vertical, 8)
            Button {
                Task { await store.addAccount() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(theme.textMuted)
                    Text("filter.addAccount")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 280)
    }

    private var shownCount: Int {
        store.lists.filter { !store.hiddenListIDs.contains($0.id) && store.isAccountVisible($0.accountID) }.count
    }

    @ViewBuilder private func accountSection(_ account: Account) -> some View {
        HStack(spacing: 8) {
            AccountAvatar(account: account, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(account.email)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.textMuted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.isAccountVisible(account.id) },
                set: { _ in store.toggleAccountVisible(account.id) }))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.vertical, 6)

        ForEach(store.lists.filter { $0.accountID == account.id }) { list in
            HStack(spacing: 8) {
                Text(list.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(store.incompleteCount(inList: list.id))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textFaint)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { !store.hiddenListIDs.contains(list.id) },
                    set: { _ in store.toggleListVisible(list.id) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.leading, 28)
            .padding(.vertical, 3)
            .opacity(store.isAccountVisible(account.id) ? 1 : 0.4)
        }
        // List add/rename/delete now lives in the dedicated list-manager modal
        // (the checklist button in the filter row); this panel only filters.
    }
}

extension Notification.Name {
    static let editTask = Notification.Name("TaskOcean.editTask")
    static let quickCapture = Notification.Name("TaskOcean.quickCapture")
    static let toggleMainWindow = Notification.Name("TaskOcean.toggleMainWindow")
}
