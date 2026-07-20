import SwiftUI

/// Search input row (FR-6.4), replaces the date nav while active.
struct SearchBar: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.iconMuted)
            TextField(text: Binding(get: { store.searchQuery },
                                    set: { store.searchQuery = $0 })) {
                Text("search.placeholder")
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(theme.textPrimary)
            .focused($focused)
            .onExitCommand { closeSearch() }
            Button { closeSearch() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 15).padding(.top, 2).padding(.bottom, 10)
        .onAppear { focused = true }
    }

    private func closeSearch() {
        store.searchActive = false
        store.searchQuery = ""
    }
}

/// Search results list. Each hit reveals its day on click.
struct SearchResults: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        let results = store.searchResults
        ScrollView {
            LazyVStack(spacing: 0) {
                if store.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    hintView("search.typeToSearch")
                } else if results.isEmpty {
                    hintView("search.noResults")
                } else {
                    ForEach(results) { task in
                        Button { store.reveal(task) } label: {
                            HStack(spacing: 10) {
                                Checkbox(isCompleted: task.isCompleted, size: 16) {
                                    store.toggleComplete(task.id)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundStyle(task.isCompleted ? theme.textFaint : theme.textPrimary)
                                        .strikethrough(task.isCompleted, color: theme.checkboxRing)
                                        .lineLimit(1)
                                    Text(subtitle(task))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(theme.textMuted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                if let account = store.account(task.accountID) {
                                    AccountAvatar(account: account, size: 16)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 2)
        }
        .scrollIndicators(.never)
    }

    private func subtitle(_ task: TaskItem) -> String {
        let listName = store.list(task.listID)?.title ?? ""
        if let due = task.due {
            let df = DateFormatter(); df.locale = AppLocale.current
            df.setLocalizedDateFormatFromTemplate("MMMd")
            return "\(listName) · \(df.string(from: due))"
        }
        return listName
    }

    private func hintView(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(theme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
    }
}
