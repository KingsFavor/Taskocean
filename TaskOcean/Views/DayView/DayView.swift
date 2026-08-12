import SwiftUI

/// The full (확장) day view — the product's main surface (design section 01).
struct DayView: View {
    @Environment(AppStore.self) private var store
    @Environment(UpdateChecker.self) private var updates
    @Environment(\.theme) private var theme

    var body: some View {
        let content = store.dayContent
        VStack(spacing: 0) {
            // Quiet, dismissible "new version" strip — only the full view shows it
            // (mini/compact stay minimal by design; Settings always carries it too).
            if updates.isBannerVisible {
                UpdateBanner()
            }
            // Header zone (date + account + progress) — tinted panel so it reads
            // as separated from the task area below.
            VStack(spacing: 0) {
                WindowChrome()
                if store.searchActive {
                    SearchBar()
                } else {
                    DateNavBar()
                    progressRow
                    FilterBar()
                }
            }
            .background(theme.panel)
            .overlay(alignment: .bottom) { Rectangle().fill(theme.divider).frame(height: 1) }

            if store.searchActive {
                SearchResults()
            } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Re-auth banners (one per expired account, non-blocking).
                    ForEach(store.reauthNeeded) { account in
                        ReauthBanner(account: account)
                    }

                    // The selected day leads — no text header (the date is at the top).
                    if !content.today.isEmpty {
                        accountSplit(content.today, section: "today") { TaskCardView(node: $0).equatable() }
                    }

                    // Overdue — secondary, so it sits just above Inbox and starts
                    // collapsed. Urgency is carried by the tinted title alone (no icon).
                    if !content.overdue.isEmpty {
                        SectionHeader(title: AppLocale.string("overdue.title", "Overdue"),
                                      done: store.tally(content.overdue).done,
                                      total: store.tally(content.overdue).total,
                                      isCollapsed: !store.overdueExpanded,
                                      accent: Color(hex: "#B08363"),
                                      titleColor: Color(hex: "#B08363"),
                                      onToggle: { withAnimation(.easeOut(duration: 0.16)) { store.overdueExpanded.toggle() } })
                        if store.overdueExpanded {
                            ForEach(content.overdue) { OverdueCardView(node: $0).equatable() }
                        }
                    }

                    // Inbox (no date) — always present if non-empty. Collapsible.
                    if !content.inbox.isEmpty {
                        SectionHeader(title: AppLocale.string("inbox.header", "No date"),
                                      done: store.tally(content.inbox).done,
                                      total: store.tally(content.inbox).total,
                                      isCollapsed: !store.inboxExpanded,
                                      onToggle: { withAnimation(.easeOut(duration: 0.16)) { store.inboxExpanded.toggle() } })
                        if store.inboxExpanded {
                            accountSplit(content.inbox, section: "inbox") { InboxRowView(node: $0).equatable() }
                        }
                    }

                    if content.isEmpty {
                        DayEmptyView()
                    }
                    Color.clear.frame(height: 4)
                }
                // Single account renders no AccountSubHeader, which normally
                // supplies the 14pt breathing room under the filter bar — make
                // up the difference so the first card never hugs the divider.
                .padding(.top, store.accounts.count > 1 ? 2 : 14)
            }
            .scrollIndicators(.never)
            // Fills the resizable window; a long day scrolls. Window size is the
            // user's — dragged, or snapped to the mode default on switch.
            .frame(maxHeight: .infinity)
            }

            QuickAddFooter()
        }
        .background(theme.window)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { store.moveSelection(-1); return .handled }
        .onKeyPress(.downArrow) { store.moveSelection(1); return .handled }
        .onKeyPress(keys: [.return]) { press in
            guard let id = store.selectedTaskID else { return .ignored }
            if press.modifiers.contains(.command) {
                store.toggleComplete(id)      // ⌘⏎ = 완료 (design section 06)
            } else {
                NotificationCenter.default.post(name: .editTask, object: id)  // ⏎ = 편집
            }
            return .handled
        }
        .onKeyPress(keys: [KeyEquivalent(" ")]) { _ in
            if let id = store.selectedTaskID { store.toggleComplete(id); return .handled }
            return .ignored
        }
    }

    /// Day progress gauge under the date header (hidden when the day is empty).
    @ViewBuilder private var progressRow: some View {
        let p = store.dayProgress
        if p.total > 0 {
            ProgressGauge(done: p.done, total: p.total)
                .padding(.horizontal, 16).padding(.bottom, 11)
        }
    }

    /// Renders nodes grouped by account (with a sub-header per account) when more
    /// than one account is present; otherwise a plain run. Reordering is only
    /// possible within one account, so the split makes those boundaries clear.
    /// One rendered line in a section: either an account header or a task row.
    /// Ids are `section`-prefixed so sibling sections never collide in the LazyVStack.
    private struct SplitRow: Identifiable {
        let id: String
        let section: String
        var header: Account? = nil
        var done: Int = 0
        var total: Int = 0
        var collapsed: Bool = false
        var node: TaskNode? = nil
    }

    private func splitRows(_ nodes: [TaskNode], section: String) -> [SplitRow] {
        guard store.accounts.count > 1 else {
            return nodes.map { SplitRow(id: "\(section)-\($0.id)", section: section, node: $0) }
        }
        var rows: [SplitRow] = []
        for group in store.byAccount(nodes) {
            let collapsed = store.isAccountSectionCollapsed(section, group.account.id)
            let t = store.tally(group.nodes)
            rows.append(SplitRow(id: "\(section)-hdr-\(group.account.id)", section: section,
                                 header: group.account, done: t.done, total: t.total, collapsed: collapsed))
            if !collapsed {
                for n in group.nodes {
                    rows.append(SplitRow(id: "\(section)-\(n.id)", section: section, node: n))
                }
            }
        }
        return rows
    }

    @ViewBuilder
    private func accountSplit<Row: View>(_ nodes: [TaskNode], section: String,
                                         @ViewBuilder row: @escaping (TaskNode) -> Row) -> some View {
        // Multi-account: a collapsible account header per run (identity moves to the
        // header, so cards drop their avatar). Single account: plain run, no header.
        ForEach(splitRows(nodes, section: section)) { r in
            if let account = r.header {
                AccountSubHeader(account: account, done: r.done, total: r.total, isCollapsed: r.collapsed) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        store.toggleAccountSection(r.section, account.id)
                    }
                }
            } else if let node = r.node {
                row(node)
            }
        }
    }
}

/// Lightweight row for inbox tasks (design: dashed check, no card).
struct InboxRowView: View, Equatable {
    static func == (lhs: InboxRowView, rhs: InboxRowView) -> Bool { lhs.node == rhs.node }
    let node: TaskNode
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var dropEdge: VerticalEdge?
    @State private var rowHeight: CGFloat = 0

    private var isSelected: Bool { store.selectedTaskID == node.task.id }

    var body: some View {
        HStack(spacing: 10) {
            Checkbox(isCompleted: node.task.isCompleted, dashed: true, size: 18) {
                store.toggleComplete(node.task.id)
            }
            Text(node.task.title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(node.task.isCompleted ? theme.textFaint : theme.textSecondary)
                .strikethrough(node.task.isCompleted, color: theme.checkboxRing)
                .lineLimit(1)
                .truncationMode(.tail)
                // Double-click to edit — scoped to the title so it never delays the
                // checkbox tap (whole-row double-tap made single taps wait ~0.3s).
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { NotificationCenter.default.post(name: .editTask, object: node.task.id) }
            Spacer(minLength: 8)
            // Same list tag as the day cards — the inbox is grouped by account, so
            // the list would otherwise be the one thing you couldn't see here.
            if !node.task.isCompleted, let list = store.list(node.task.listID) {
                ListTag(title: list.title)
            }
        }
        .padding(.horizontal, 21).padding(.vertical, 7)
        .background(isSelected ? theme.panel.opacity(0.6) : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .top) {
            if dropEdge == .top { dropLine }
        }
        .overlay(alignment: .bottom) {
            if dropEdge == .bottom { dropLine }
        }
        .padding(.horizontal, 4)
        .background(GeometryReader { g in
            Color.clear.preference(key: CardHeightKey.self, value: g.size.height)
        })
        .onPreferenceChange(CardHeightKey.self) { rowHeight = $0 }
        .onDrag {
            store.draggingID = node.task.id
            return NSItemProvider(object: node.task.id as NSString)
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(
            targetID: node.task.id, store: store, height: rowHeight, edge: $dropEdge))
        .contextMenu { TaskContextMenu(node: node) }
    }

    private var dropLine: some View {
        Capsule().fill(theme.textPrimary).frame(height: 2).padding(.horizontal, 21)
    }
}

/// Overdue card — like a task card, tinted by the overdue detail line.
/// "오늘로 이동" lives in the right-click menu (A29), not as an inline button.
struct OverdueCardView: View, Equatable {
    static func == (lhs: OverdueCardView, rhs: OverdueCardView) -> Bool { lhs.node == rhs.node }
    let node: TaskNode
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Checkbox(isCompleted: node.task.isCompleted, size: 19) {
                store.toggleComplete(node.task.id)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(node.task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                if let due = node.task.due {
                    Text(DayFormatter.overdueDetail(due: due, today: Date()))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color(hex: "#B08363"))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                if !node.task.isCompleted, let list = store.list(node.task.listID) {
                    ListTag(title: list.title)
                }
                if let account = store.account(node.task.accountID) {
                    AccountAvatar(account: account)
                }
            }
            .layoutPriority(1)      // never let a long title squeeze the tag away
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: theme.cardRadius).fill(theme.card))
        .overlay(RoundedRectangle(cornerRadius: theme.cardRadius).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 12).padding(.bottom, 8)
        .contextMenu { TaskContextMenu(node: node) }
    }
}

/// Shown when the selected day + inbox are entirely empty.
struct DayEmptyView: View {
    @Environment(\.theme) private var theme
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(theme.textFaint)
            Text("day.empty")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

