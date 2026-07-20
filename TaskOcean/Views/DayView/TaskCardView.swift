import SwiftUI

/// A single top-level task rendered as a raised card (design section 01).
/// One line when there's no note; a disclosure chevron on the left signals
/// expandable subtasks. No relative date badge (the date lives in the header).
struct TaskCardView: View, Equatable {
    let node: TaskNode
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var showSubtasks = false
    @State private var newSubtask = ""
    @State private var addingSubtask = false
    @FocusState private var addFocused: Bool
    @State private var dropEdge: VerticalEdge?
    @State private var cardHeight: CGFloat = 0
    @State private var celebrating = false
    @State private var pop = false

    /// Skip re-rendering cards whose data didn't change. Completing a task
    /// rebuilds *every* TaskNode (dayContent is recomputed), which would otherwise
    /// re-render every visible card; only the changed one should update. Selection
    /// and theme still update — the card observes those (@Observable / @Environment)
    /// independently of this parent-driven equality gate.
    static func == (lhs: TaskCardView, rhs: TaskCardView) -> Bool {
        lhs.node == rhs.node
    }

    private var task: TaskItem { node.task }
    private var account: Account? { store.account(task.accountID) }
    /// FR-AUTH-4: tasks of an expired account stay visible but clearly marked.
    private var needsReauth: Bool { account?.sessionState == .needsReauth }
    private var isSelected: Bool { store.selectedTaskID == task.id }
    private var listTitle: String? { store.list(task.listID)?.title }
    /// Notes only render when present, on an incomplete task → otherwise 1 line.
    private var showsNotes: Bool {
        guard !task.isCompleted, !needsReauth, let n = task.notes else { return false }
        return !n.isEmpty
    }
    private var rowAlignment: VerticalAlignment { showsNotes ? .top : .center }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: rowAlignment, spacing: 9) {
                Checkbox(isCompleted: task.isCompleted, size: 19) {
                    store.toggleComplete(task.id)
                }
                .disabled(needsReauth)
                .scaleEffect(pop ? 1.22 : 1)
                .overlay { if celebrating { CelebrationBurst(color: theme.syncOK) } }

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(task.isCompleted || needsReauth ? theme.textFaint : theme.textPrimary)
                        .strikethrough(task.isCompleted, color: theme.checkboxRing)
                        .lineLimit(showsNotes ? 2 : 1)

                    if needsReauth {
                        Text("reauth.needed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(account?.colorSeed.accent ?? theme.textMuted)
                            .padding(.top, 2)
                    } else if showsNotes {
                        Text(task.notes ?? "")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(theme.textMuted)
                            .lineLimit(1)
                    }
                }
                // Double-click to edit — scoped to the content (not the whole card),
                // so it never delays taps on the checkbox / expand button.
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { edit() }

                Spacer(minLength: 6)

                // Trailing inline meta (no "오늘" chip — date is in the header).
                // Grouped in one centred HStack so the list tag and the progress
                // gauge line up with each other even when the row is top-aligned
                // (which it is whenever the card shows a note).
                if !task.isCompleted && !needsReauth {
                    HStack(alignment: .center, spacing: 8) {
                        // Which list this task lives in. A tag (not another section)
                        // keeps the day readable at a glance; account is the group.
                        if let listTitle {
                            ListTag(title: listTitle)
                        }
                        if task.syncState != .synced {
                            SyncStateBadge(state: task.syncState)
                        }
                        if node.hasSubtasks {
                            // Expand/collapse control at the right end, with a large
                            // tap area. Shows the subtask progress meter + a chevron.
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) { showSubtasks.toggle() }
                            } label: {
                                HStack(spacing: 8) {
                                    SubtaskProgress(done: node.subtaskDone, total: node.subtaskTotal)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(theme.iconMuted)
                                        .rotationEffect(.degrees(showSubtasks ? 90 : 0))
                                }
                                .padding(.vertical, 9).padding(.leading, 9).padding(.trailing, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    // Keep the meta intact; let the long title truncate instead.
                    .layoutPriority(1)
                }
            }

            if showSubtasks, node.hasSubtasks {
                subtaskList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13).padding(.vertical, 12)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cardRadius)
                .stroke(isSelected ? (account?.colorSeed.accent ?? theme.textPrimary) : theme.cardBorder,
                        lineWidth: isSelected ? 1.8 : 1)
        )
        // Insertion line ABOVE (dropping this card's spot) or BELOW (dropping after,
        // i.e. moving a task down / to the very bottom). Direction comes from which
        // task is being dragged relative to this one.
        .overlay(alignment: .top) {
            if dropEdge == .top { dropLine }
        }
        .overlay(alignment: .bottom) {
            if dropEdge == .bottom { dropLine }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        // NOTE: no card-level `.onTapGesture(count: 2)` — a container double-tap
        // gesture makes single taps on the inner checkbox / expand button wait for
        // the double-click timeout (that was the "sluggish" feel). Double-click to
        // edit lives on the content above; a *drag* (movement) still works from the
        // whole card, while a plain click passes through to the inner controls.
        .onChange(of: task.isCompleted) { old, new in
            guard new && !old else { return }
            pop = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = false }
            celebrating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { celebrating = false }
        }
        .background(GeometryReader { g in
            Color.clear.preference(key: CardHeightKey.self, value: g.size.height)
        })
        .onPreferenceChange(CardHeightKey.self) { cardHeight = $0 }
        .onDrag {
            store.draggingID = task.id   // remember what's dragged
            return NSItemProvider(object: task.id as NSString)
        } preview: {
            Text(task.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 220, alignment: .leading)   // long titles → no giant preview
                .padding(8)
                .background(theme.card, in: RoundedRectangle(cornerRadius: 8))
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(
            targetID: task.id, store: store, height: cardHeight, edge: $dropEdge))
        .contextMenu { TaskContextMenu(node: node) }
    }

    private var dropLine: some View {
        Capsule().fill(account?.colorSeed.accent ?? theme.textPrimary)
            .frame(height: 2).padding(.horizontal, 16)
    }

    private func edit() {
        NotificationCenter.default.post(name: .editTask, object: task.id)
    }

    // MARK: Subtasks (1 level, inline — design section 06)
    @ViewBuilder private var subtaskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(node.subtasks) { sub in
                HStack(spacing: 9) {
                    Rectangle().fill(theme.cardBorder).frame(width: 1, height: 18)
                        .padding(.leading, 4)
                    Checkbox(isCompleted: sub.isCompleted, size: 16) {
                        store.toggleComplete(sub.id)
                    }
                    Text(sub.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(sub.isCompleted ? theme.textFaint : theme.textSecondary)
                        .strikethrough(sub.isCompleted, color: theme.checkboxRing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
            // Add-subtask row (1-level only — API constraint §8.4.2). The TextField
            // is deferred behind a button: instantiating an NSTextField-backed field
            // is expensive, so expanding a card just to VIEW subtasks stays cheap.
            HStack(spacing: 9) {
                Rectangle().fill(theme.cardBorder).frame(width: 1, height: 18)
                    .padding(.leading, 4)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textFaint)
                    .frame(width: 16)
                if addingSubtask {
                    TextField(text: $newSubtask) { Text("editor.addSubtask") }
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .focused($addFocused)
                        .onSubmit(addSubtask)
                } else {
                    Button {
                        addingSubtask = true
                        addFocused = true
                    } label: {
                        Text("editor.addSubtask")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.textFaint)
                        Spacer(minLength: 0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.top, 8)
        .padding(.leading, 6)
    }

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.addTask(title: title, listID: task.listID, due: task.due, parentID: task.id)
        newSubtask = ""
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: theme.cardRadius)
            .fill(task.isCompleted ? theme.cardMuted : theme.card)
            .shadow(color: task.isCompleted ? .clear : Color.black.opacity(theme.isDark ? 0 : 0.06),
                    radius: 8, x: 0, y: 5)
    }
}

/// A brief one-shot burst (ring + sparks) played when a task is completed.
/// Only mounted while celebrating (parent gates it with `if celebrating`), so
/// idle cards don't carry these shapes — it plays once on appear. Non-interactive.
/// Row height, so the drop delegate can split the card into top/bottom halves.
struct CardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CelebrationBurst: View {
    var color: Color
    @State private var play = false

    private let dirs: [(CGFloat, CGFloat)] = [
        (1, 0), (0.5, 0.87), (-0.5, 0.87), (-1, 0), (-0.5, -0.87), (0.5, -0.87)
    ]

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 2)
                .scaleEffect(play ? 2.3 : 0.5)
                .opacity(play ? 0 : 0.9)
            ForEach(0..<dirs.count, id: \.self) { i in
                Circle().fill(color).frame(width: 3.5, height: 3.5)
                    .offset(x: play ? dirs[i].0 * 15 : 0, y: play ? dirs[i].1 * 15 : 0)
                    .opacity(play ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { play = true }
        }
    }
}
