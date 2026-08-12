import SwiftUI

/// Top-level container. Chooses first-run onboarding vs. the active window mode,
/// and hosts the editor sheet. Everything is themed from the current color scheme.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingTaskID: String?

    var body: some View {
        Group {
            if !store.hasAccounts {
                FirstRunView()
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                // Each mode fills the window (min size = its legible floor, then the
                // user's drag governs). Content scrolls when it overflows the frame.
                // Top alignment keeps the strip modes pinned to the top when a taller
                // window leaves slack below.
                switch store.windowMode {
                case .mini:
                    MiniStrip()
                        .frame(minWidth: 300, maxWidth: .infinity,
                               minHeight: 56, maxHeight: .infinity, alignment: .top)
                case .compact:
                    CompactStrip()
                        .frame(minWidth: 300, maxWidth: .infinity,
                               minHeight: 150, maxHeight: .infinity, alignment: .top)
                case .full:
                    DayView()
                        .frame(minWidth: 384, maxWidth: .infinity,
                               minHeight: 320, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .provideTheme(colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        // Rebuild the whole subtree on a language switch so imperative localized
        // strings (AppLocale.string) and DateFormatter output re-evaluate live —
        // SwiftUI's \.locale only refreshes Text("key"), not those paths.
        .id(store.language)
        .sheet(item: $editingTaskID) { id in
            TaskEditorView(taskID: id).environment(store).provideTheme(colorScheme)
        }
        .confirmationDialog(
            Text("task.delete.confirm"),
            isPresented: Binding(get: { store.pendingDeleteTaskID != nil },
                                 set: { if !$0 { store.pendingDeleteTaskID = nil } }),
            presenting: store.pendingDeleteTaskID
        ) { id in
            Button(role: .destructive) { store.deleteTask(id) } label: { Text("menu.delete") }
            Button(role: .cancel) {} label: { Text("action.cancel") }
        } message: { _ in
            Text("task.delete.message")
        }
        .onReceive(NotificationCenter.default.publisher(for: .editTask)) { note in
            if let id = note.object as? String { editingTaskID = id }
        }
    }
}

// Allow using a String id directly with `.sheet(item:)`.
extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Mini strip (count only)

struct MiniStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                HStack(spacing: 9) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Text("mini.remaining \(store.remainingTodayCount)")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    AccountAvatarStack(accounts: store.accounts, size: 16)
                    WindowModePicker()
                }
                let p = store.dayProgress
                if p.total > 0 {
                    ProgressGauge(done: p.done, total: p.total, height: 5, showLabel: false)
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 10)
            Spacer(minLength: 0)   // fill a taller window; content pins to the top
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.window.opacity(0.92))
        .background(WindowDragArea())   // whole strip is a move handle
    }
}

// MARK: - Compact strip (titles only)

struct CompactStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    @ViewBuilder private func compactList(_ rows: [TaskNode]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { node in
                CompactTaskRow(node: node).equatable()
            }
        }
        .padding(.vertical, 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Text(compactHeader)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 0)
                WindowModePicker()
            }
            .padding(.horizontal, 13).padding(.top, 9).padding(.bottom, 8)
            .background(WindowDragArea())   // header = window move handle

            let p = store.dayProgress
            if p.total > 0 {
                ProgressGauge(done: p.done, total: p.total, height: 5)
                    .padding(.horizontal, 14).padding(.top, 7).padding(.bottom, 8)
            }
            Divider().overlay(theme.divider)

            // Fills the resizable window; overflow scrolls. (The window's size is
            // the user's — set by drag, or snapped to the mode default on switch.)
            let rows = store.dayContent.today
            ScrollView {
                compactList(rows)
            }
            .scrollIndicators(.never)
            .frame(maxHeight: .infinity)

            addHint   // compact has no add field → point to the global shortcut
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.window.opacity(0.94))
    }

    /// Faint footer: "태스크 추가 : ⌥Space" (uses the configured capture hotkey).
    private var addHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "plus.circle")
                .font(.system(size: 10, weight: .semibold))
            Text("\(AppLocale.string("compact.addHint", "Add task")) : ")
                .font(.system(size: 10.5, weight: .medium))
            Text(HotKeyPreferences.capture.display)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.textFaint)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .overlay(alignment: .top) { Divider().overlay(theme.divider) }
    }

    private var compactHeader: String {
        let d = DayFormatter.headerTitle(store.selectedDay)
        return store.isViewingToday
            ? AppLocale.string("today.header", "Today") + " · " + d
            : d
    }
}

// MARK: - Compact task row (title + expandable subtasks)

/// One compact-strip row: checkbox + title, with a left disclosure to expand
/// subtasks inline (each toggleable). Reserves the disclosure slot so checkboxes
/// stay aligned whether or not a row has subtasks.
struct CompactTaskRow: View, Equatable {
    static func == (lhs: CompactTaskRow, rhs: CompactTaskRow) -> Bool { lhs.node == rhs.node }
    let node: TaskNode
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Group {
                    if node.hasSubtasks {
                        Button {
                            withAnimation(.easeOut(duration: 0.16)) { expanded.toggle() }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.iconMuted)
                                .rotationEffect(.degrees(expanded ? 90 : 0))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 10)

                Checkbox(isCompleted: node.task.isCompleted, size: 16) {
                    store.toggleComplete(node.task.id)
                }
                Text(node.task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(node.task.isCompleted ? theme.textFaint : theme.textPrimary)
                    .strikethrough(node.task.isCompleted, color: theme.checkboxRing)
                    .lineLimit(1)
                if node.hasSubtasks {
                    Text("\(node.subtaskDone)/\(node.subtaskTotal)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textFaint)
                        .monospacedDigit()
                }
                Spacer(minLength: 6)
                // List tag — same trailing slot as the full view, so the eye finds
                // "which list" in one place across modes. Account stays the avatar.
                if !node.task.isCompleted, let list = store.list(node.task.listID) {
                    ListTag(title: list.title, maxWidth: 74, fontSize: 9.5)   // strip is narrow
                }
                if let account = store.account(node.task.accountID) {
                    AccountAvatar(account: account, size: 16)
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 8)

            if expanded, node.hasSubtasks {
                VStack(spacing: 0) {
                    ForEach(node.subtasks) { sub in
                        HStack(spacing: 8) {
                            // Guide line + indent so subtasks sit under the parent title.
                            Rectangle().fill(theme.cardBorder)
                                .frame(width: 1, height: 16)
                            Checkbox(isCompleted: sub.isCompleted, size: 14) {
                                store.toggleComplete(sub.id)
                            }
                            Text(sub.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(sub.isCompleted ? theme.textFaint : theme.textSecondary)
                                .strikethrough(sub.isCompleted, color: theme.checkboxRing)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 50).padding(.trailing, 13).padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Update banner (quiet "new version available" strip)

/// Slim, single-line, dismissible. Tapping the label opens the release page;
/// ✕ skips this version so it never nags again. Never steals focus (no modal).
struct UpdateBanner: View {
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.syncOK)
            Button {
                updates.openReleasePage()
            } label: {
                HStack(spacing: 5) {
                    Text("\(AppLocale.string("update.available", "New version")) \(updates.latestVersion ?? "")")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Text("update.action")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(theme.syncOK)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text(verbatim: UpdateChecker.brewUpgradeCommand))   // brew hint on hover

            Spacer(minLength: 0)

            Button {
                updates.dismissBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.iconMuted)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text("update.dismiss"))
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(theme.infoSurface)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.divider).frame(height: 1) }
    }
}

// MARK: - Re-auth banner (design section 05)

struct ReauthBanner: View {
    let account: Account
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            AccountAvatar(account: account, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("reauth.needed")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Text(account.email)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.textMuted)
            }
            Spacer(minLength: 0)
            Button {
                Task { await store.reauthenticate(account.id) }
            } label: {
                HStack(spacing: 6) {
                    if account.sessionState == .refreshing {
                        ProgressView().controlSize(.mini).tint(.white)
                    }
                    Text(account.sessionState == .refreshing ? "reauth.signingIn" : "reauth.signIn")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(account.colorSeed.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(account.sessionState == .refreshing)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(account.colorSeed.chipBackground(dark: theme.isDark),
                    in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12).padding(.top, 8)
    }
}
