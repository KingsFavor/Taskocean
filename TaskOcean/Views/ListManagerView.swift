import SwiftUI

/// Dedicated list-management modal (add / rename / delete), reached from the
/// list button in the filter row. Separated from the account filter popover,
/// which now only toggles visibility.
struct ListManagerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var editingID: String?
    @State private var draft = ""
    @State private var pendingDelete: TaskList?
    @FocusState private var focusedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("lists.manage.title")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button { dismiss() } label: { Text("action.done") }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            Divider().overlay(theme.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.accounts) { account in
                        accountSection(account)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .frame(width: 410, height: 480)
        .background(theme.window)
        .confirmationDialog(
            Text("lists.delete.confirm"),
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { list in
            Button(role: .destructive) { store.deleteList(list.id) } label: {
                Text("menu.deleteList")
            }
            Button(role: .cancel) {} label: { Text("action.cancel") }
        } message: { _ in
            Text("lists.delete.message")
        }
    }

    @ViewBuilder private func accountSection(_ account: Account) -> some View {
        HStack(spacing: 8) {
            AccountAvatar(account: account, size: 20)
            Text(account.displayName)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text(account.email)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(theme.textMuted)
            Spacer(minLength: 0)
        }
        .padding(.top, 14).padding(.bottom, 7)

        let lists = store.lists(inAccount: account.id)
        ForEach(lists) { list in
            listRow(list, canDelete: lists.count > 1)
        }

        Button {
            let created = store.addList(accountID: account.id,
                                        title: AppLocale.string("list.newDefault", "New list"))
            beginRename(created)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(account.colorSeed.accent)
                Text("filter.addList")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, 6).padding(.leading, 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func listRow(_ list: TaskList, canDelete: Bool) -> some View {
        let editing = editingID == list.id
        HStack(spacing: 10) {
            Image(systemName: "list.bullet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.iconMuted)
                .frame(width: 14)

            if editing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .focused($focusedField, equals: list.id)
                    .onSubmit { commitRename(list) }
            } else {
                Text(list.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(store.incompleteCount(inList: list.id))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textFaint)
            }

            Spacer(minLength: 8)

            if editing {
                iconButton("checkmark") { commitRename(list) }
            } else {
                iconButton("pencil") { beginRename(list) }             // 수정
                    .help(Text("action.rename"))
                Menu {
                    Button("menu.clearCompleted") { store.clearCompleted(listID: list.id) }
                    Divider()
                    Button(role: .destructive) { pendingDelete = list } label: {
                        Text("menu.deleteList")
                    }
                    .disabled(!canDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.iconMuted)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
        .padding(.vertical, 2)
    }

    private func iconButton(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func beginRename(_ list: TaskList) {
        editingID = list.id
        draft = list.title
        focusedField = list.id
    }

    private func commitRename(_ list: TaskList) {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { store.renameList(list.id, title: title) }
        editingID = nil
        focusedField = nil
    }
}
