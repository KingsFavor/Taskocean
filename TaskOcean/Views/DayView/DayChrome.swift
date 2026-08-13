import SwiftUI

// MARK: - Window chrome (top row: mode toggle + pin)

struct WindowChrome: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            // Real traffic lights live top-left (hidden titlebar); leave room.
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                DevBadge()
                Button {
                    store.alwaysOnTop.toggle()
                } label: {
                    Image(systemName: store.alwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(store.alwaysOnTop ? theme.textSecondary : theme.iconMuted)
                }
                .buttonStyle(.plain)
                .help(Text("chrome.alwaysOnTop"))

                WindowModePicker()
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 36)
        .background(WindowDragArea())   // top chrome = window move handle
    }
}

struct WindowModePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WindowMode.allCases) { mode in
                let selected = store.windowMode == mode
                Button {
                    // No withAnimation: animating the window content-size change can
                    // trip an AppKit constraint exception mid-resize. Switch atomically.
                    store.windowMode = mode
                } label: {
                    iconView(mode, selected: selected)
                        .frame(width: 24, height: 20)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.isDark ? theme.panelStrong : theme.window)
                                    .shadow(color: .black.opacity(theme.isDark ? 0 : 0.08), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(label(mode))   // mode name shows only on hover (tooltip)
            }
        }
        .padding(2)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
    }

    /// mini = short landscape rectangle, compact = same width but a bit taller,
    /// full = fullscreen-style expand arrows.
    @ViewBuilder
    private func iconView(_ mode: WindowMode, selected: Bool) -> some View {
        let color = selected ? theme.textPrimary : theme.textMuted
        switch mode {
        case .mini:
            RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: 1.5)
                .frame(width: 14, height: 8)
        case .compact:
            RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: 1.5)
                .frame(width: 14, height: 11)
        case .full:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: selected ? .bold : .semibold))
                .foregroundStyle(color)
        }
    }

    private func label(_ mode: WindowMode) -> LocalizedStringKey {
        switch mode {
        case .mini: return "mode.mini"
        case .compact: return "mode.compact"
        case .full: return "mode.full"
        }
    }
}

// MARK: - Date navigation

struct DateNavBar: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            navButton(system: "chevron.left") { store.goToPreviousDay() }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(DayFormatter.headerTitle(store.selectedDay))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Text(DayFormatter.weekday(store.selectedDay))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.textMuted)
                    if store.isViewingToday {
                        RelativeChip(text: AppLocale.string("badge.today", "Today"))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { store.goToToday() }
            .help(Text("nav.goToToday"))
            Spacer(minLength: 0)
            navButton(system: "chevron.right") { store.goToNextDay() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2).padding(.bottom, 14)
    }

    private func navButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 30, height: 30)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter row (account dropdown + avatar stack + grid/search)

struct FilterBar: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var showFilterPanel = false
    @State private var showHeatmap = false
    @State private var showListManager = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showFilterPanel.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("filter.allAccounts")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.iconMuted)
                }
                .padding(.leading, 10).padding(.trailing, 9).padding(.vertical, 5)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFilterPanel, arrowEdge: .bottom) {
                FilterPanel().environment(store).provideTheme(colorScheme)
            }

            AccountAvatarStack(accounts: store.accounts)

            Spacer(minLength: 0)

            // Dedicated list management (add / rename / delete) — separated from
            // the account filter popover, which now only toggles visibility.
            Button {
                showListManager = true
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(theme.iconMuted)
            }
            .buttonStyle(.plain)
            .help(Text("lists.manage.help"))
            .sheet(isPresented: $showListManager) {
                ListManagerView().environment(store).provideTheme(colorScheme)
            }

            Button {
                showHeatmap.toggle()
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(theme.iconMuted)
            }
            .buttonStyle(.plain)
            .help(Text("heatmap.help"))
            .popover(isPresented: $showHeatmap, arrowEdge: .bottom) {
                HeatmapView().environment(store).provideTheme(colorScheme)
            }

            Button {
                store.searchActive.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(store.searchActive ? theme.textSecondary : theme.iconMuted)
            }
            .buttonStyle(.plain)
            .help(Text("search.help"))
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 8)
    }
}

// MARK: - Quick add footer

struct QuickAddFooter: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var draft = ""
    @State private var due: Date? = nil
    @State private var dueTouched = false
    @FocusState private var focused: Bool

    /// Default due = the day currently being viewed, until the user picks one.
    private var effectiveDue: Binding<Date?> {
        Binding(get: { dueTouched ? due : store.selectedDay },
                set: { due = $0; dueTouched = true })
    }

    private var listBinding: Binding<String> {
        Binding(get: { store.composeTargetListID }, set: { store.composeTargetListID = $0 })
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.iconMuted)
                TextField(text: $draft) {
                    Text("quickadd.placeholder")
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .focused($focused)
                .onSubmit(submit)
                SyncDot()
            }
            HStack(spacing: 8) {
                ComposeDatePill(due: effectiveDue)
                ComposeListPill(listID: listBinding)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 15).padding(.top, 10).padding(.bottom, 10)
        .background(theme.panel)   // distinct from the task area (separation)
        .overlay(alignment: .top) { Divider().overlay(theme.divider) }
    }

    private func submit() {
        let raw = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        // A typed date word (NLP) wins; otherwise the date pill's value (which
        // defaults to the viewed day). "없음" on the pill → Inbox (PRD §6.6).
        let parsed = NaturalDateParser.parse(raw)
        let resolved = parsed.matchedToken != nil ? parsed.due : effectiveDue.wrappedValue
        store.addTask(title: parsed.title, due: resolved.map(CalendarSupport.startOfDay))
        draft = ""
        due = nil
        dueTouched = false
    }
}

/// The small ambient sync indicator: green = synced, amber = pending (queued in the
/// outbox), red = error/conflict. Quiet by design — a color, never a blocking alert.
struct SyncDot: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    var body: some View {
        let status = store.syncStatus
        Circle()
            .fill(color(for: status))
            .frame(width: 8, height: 8)
            .help(Text(tooltip(for: status)))
    }

    private func color(for status: SyncState) -> Color {
        switch status {
        case .synced: theme.syncOK
        case .pending: theme.syncPending
        case .conflict, .error: theme.syncError
        }
    }

    private func tooltip(for status: SyncState) -> LocalizedStringKey {
        switch status {
        case .synced: "sync.synced"
        case .pending: "sync.pending"
        case .conflict, .error: "sync.error"
        }
    }
}
