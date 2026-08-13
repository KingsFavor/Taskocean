import SwiftUI
import Observation

/// Window presentation mode (design: 미니 / 컴팩트 / 확장).
enum WindowMode: String, CaseIterable, Identifiable {
    case mini      // thin strip, count only
    case compact   // titles only
    case full      // full detail (hero)
    var id: String { rawValue }
}

/// Language selection (system default + manual override, PRD FR-I18N-2).
enum LanguageOption: String, CaseIterable, Identifiable {
    case system, korean, english
    var id: String { rawValue }
}

/// A parent task plus its (1-level) subtasks, ready to render as one card.
struct TaskNode: Identifiable, Hashable {
    let task: TaskItem
    let subtasks: [TaskItem]
    var id: String { task.id }

    var subtaskTotal: Int { subtasks.count }
    var subtaskDone: Int { subtasks.filter(\.isCompleted).count }
    var hasSubtasks: Bool { !subtasks.isEmpty }
    var progress: Double { subtaskTotal == 0 ? 0 : Double(subtaskDone) / Double(subtaskTotal) }
}

/// The grouped, sorted content for the currently-viewed day.
struct DayContent {
    var overdue: [TaskNode] = []   // only populated when viewing "today"
    var today: [TaskNode] = []
    var inbox: [TaskNode] = []

    var isEmpty: Bool { overdue.isEmpty && today.isEmpty && inbox.isEmpty }
}

/// View-facing application state. UI observes this; it delegates all data ops
/// to a `TaskRepository`. Everything here is `@MainActor`.
@MainActor
@Observable
final class AppStore {
    private let repo: TaskRepository

    // View state --------------------------------------------------------------
    var selectedDay: Date = CalendarSupport.startOfDay(Date()) {
        didSet { if oldValue != selectedDay { refreshDayContent() } }
    }
    var windowMode: WindowMode = .full
    var language: LanguageOption = .system {
        didSet { AppLocale.apply(language) }   // imperative strings + DateFormatters follow the switch
    }
    var alwaysOnTop: Bool = true
    var showOnAllSpaces: Bool = true
    var windowOpacity: Double = 1.0
    var showCompleted: Bool = true {
        didSet { if oldValue != showCompleted { refreshDayContent() } }
    }
    /// Both secondary sections start collapsed — the day itself is the focus.
    var overdueExpanded: Bool = false
    var inboxExpanded: Bool = false
    /// Collapsed account sub-sections, keyed "section-accountID" (e.g. "today-acc-work").
    var collapsedAccountSections: Set<String> = []
    /// Optional list-grouped rendering of the day view (§6.6 옵션, P1).
    var groupByList: Bool = false
    /// FR-1.7: fade the window while the pointer is elsewhere.
    var autoFadeEnabled: Bool = false
    /// FR-6.4: search overlay.
    var searchActive: Bool = false
    var searchQuery: String = ""
    /// FR-5.6: keyboard-selected task id in the day view.
    var selectedTaskID: String?
    /// Task currently being dragged for reorder (set on drag start). Lets a hovered
    /// card know the drag direction so it can draw the insertion line above vs below.
    var draggingID: String?
    /// Destructive-action gate: a delete request parks here until the user
    /// confirms in the dialog (RootView). nil = no pending delete.
    var pendingDeleteTaskID: String?

    /// Account chosen as the default target for the quick-add footer.
    var composeTargetListID: String

    /// Hidden accounts/lists (filter). Empty = all visible.
    var hiddenAccountIDs: Set<String> = [] {
        didSet { if oldValue != hiddenAccountIDs { refreshDayContent() } }
    }
    var hiddenListIDs: Set<String> = [] {
        didSet { if oldValue != hiddenListIDs { refreshDayContent() } }
    }

    // Snapshots (recomputed from repo on demand) ------------------------------
    private(set) var accountsSnapshot: [Account] = []
    private(set) var listsSnapshot: [TaskList] = []
    private(set) var tasksSnapshot: [TaskItem] = []

    var lastSyncedAt: Date = Date()

    init(repository: TaskRepository) {
        self.repo = repository
        self.composeTargetListID = repository.lists().first?.id ?? ""
        AppLocale.apply(language)
        reload()
        repository.onChange = { [weak self] in self?.reload() }
    }

    // MARK: Derived
    func account(_ id: String) -> Account? { accountsSnapshot.first { $0.id == id } }
    func list(_ id: String) -> TaskList? { listsSnapshot.first { $0.id == id } }

    var accounts: [Account] { accountsSnapshot }
    var lists: [TaskList] { listsSnapshot }
    var hasAccounts: Bool { !accountsSnapshot.isEmpty }

    var isViewingToday: Bool { CalendarSupport.isToday(selectedDay) }

    /// Accounts that currently need re-auth (drives banners).
    /// Banner list: includes .refreshing so the banner stays (with its button in
    /// a loading state) while the OAuth window is open, instead of vanishing the
    /// moment the flow starts and popping back on cancel.
    var reauthNeeded: [Account] {
        accountsSnapshot.filter { $0.sessionState != .active }
    }

    func accentColor(forAccount id: String) -> Color {
        account(id)?.colorSeed.accent ?? .gray
    }

    // MARK: Grouping engine (PRD §6.6)
    /// Cached so it's computed once per data/view change — not on every access
    /// (it was a computed property, recomputed dozens of times per render pass →
    /// the sluggish feel on toggle). `refreshDayContent()` rebuilds it.
    private(set) var dayContent = DayContent()

    private func refreshDayContent() { dayContent = computeDayContent() }

    /// Day progress for the gauge: completed vs total among the day's actionable
    /// tasks (overdue + selected day). Inbox (undated) is excluded.
    var dayProgress: (done: Int, total: Int) {
        let nodes = dayContent.overdue + dayContent.today
        return (nodes.filter { $0.task.isCompleted }.count, nodes.count)
    }

    private func computeDayContent() -> DayContent {
        let today = CalendarSupport.startOfDay(Date())
        let day = CalendarSupport.startOfDay(selectedDay)
        let viewingToday = CalendarSupport.isSameDay(day, today)

        // Only top-level tasks become cards; subtasks attach to their parent.
        let visibleTasks = tasksSnapshot.filter { isVisible($0) }
        let subtasksByParent = Dictionary(grouping: visibleTasks.filter { $0.isSubtask }) { $0.parentID! }

        func node(_ task: TaskItem) -> TaskNode {
            let subs = (subtasksByParent[task.id] ?? []).sorted(by: taskOrder)
            return TaskNode(task: task, subtasks: subs)
        }

        let tops = visibleTasks.filter { !$0.isSubtask }

        var content = DayContent()

        // Overdue: incomplete, due before today — only on the today view.
        if viewingToday {
            content.overdue = tops
                .filter { t in
                    guard let due = t.due, !t.isCompleted else { return false }
                    return CalendarSupport.startOfDay(due) < today
                }
                .sorted(by: taskOrder)
                .map(node)
        }

        // Day tasks: due == selected day.
        content.today = tops
            .filter { t in
                guard let due = t.due else { return false }
                return CalendarSupport.isSameDay(due, day)
            }
            .filter { showCompleted || !$0.isCompleted }
            .sorted(by: completedLast)
            .map(node)

        // Inbox: no due date. Always shown regardless of selected day.
        content.inbox = tops
            .filter { $0.due == nil }
            .filter { showCompleted || !$0.isCompleted }
            .sorted(by: completedLast)
            .map(node)

        return content
    }

    /// Completed / total tally for a group of nodes (drives "완료/전체").
    func tally(_ nodes: [TaskNode]) -> (done: Int, total: Int) {
        (nodes.filter { $0.task.isCompleted }.count, nodes.count)
    }

    /// Split already-sorted nodes into per-account runs, preserving account order.
    /// Used by the full view to separate accounts (reordering is same-account only).
    func byAccount(_ nodes: [TaskNode]) -> [(account: Account, nodes: [TaskNode])] {
        var order: [String] = []
        var map: [String: [TaskNode]] = [:]
        for n in nodes {
            let id = n.task.accountID
            if map[id] == nil { order.append(id) }
            map[id, default: []].append(n)
        }
        return order.compactMap { id in account(id).map { (account: $0, nodes: map[id] ?? []) } }
    }

    /// Count of incomplete tasks relevant to a given day — powers the heatmap density.
    func incompleteCount(on day: Date) -> Int {
        tasksSnapshot.filter { t in
            guard !t.isSubtask, !t.isCompleted, let due = t.due else { return false }
            return CalendarSupport.isSameDay(due, day)
        }.count
    }

    /// Aggregate sync state for the ambient dot (FR-SYNC-8): error/conflict wins,
    /// then pending (queued in the outbox), else synced. Quietly reflects reality
    /// instead of always claiming "synced".
    var syncStatus: SyncState {
        var pending = false
        for t in tasksSnapshot {
            switch t.syncState {
            case .error, .conflict: return .error
            case .pending: pending = true
            case .synced: break
            }
        }
        return pending ? .pending : .synced
    }

    /// Remaining (incomplete) count for the mini strip / dock badge.
    var remainingTodayCount: Int {
        let c = dayContent
        return (c.overdue + c.today).filter { !$0.task.isCompleted }.count
    }

    // MARK: Sorting helpers
    /// Account (connection order) → list → Google position (PRD §6.6).
    private func taskOrder(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.accountID != b.accountID {
            return accountIndex(a.accountID) < accountIndex(b.accountID)
        }
        if a.listID != b.listID { return listIndex(a.listID) < listIndex(b.listID) }
        return a.position < b.position
    }

    private func accountIndex(_ id: String) -> Int {
        accountsSnapshot.firstIndex { $0.id == id } ?? .max
    }

    private func listIndex(_ id: String) -> Int {
        listsSnapshot.firstIndex { $0.id == id } ?? .max
    }

    /// Same as `taskOrder` but pushes completed items to the bottom of the group.
    private func completedLast(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.isCompleted != b.isCompleted { return !a.isCompleted }
        return taskOrder(a, b)
    }

    private func isVisible(_ t: TaskItem) -> Bool {
        if hiddenAccountIDs.contains(t.accountID) { return false }
        if hiddenListIDs.contains(t.listID) { return false }
        return true
    }

    // MARK: Section collapse
    func accountSectionKey(_ section: String, _ accountID: String) -> String { "\(section)-\(accountID)" }
    func isAccountSectionCollapsed(_ section: String, _ accountID: String) -> Bool {
        collapsedAccountSections.contains(accountSectionKey(section, accountID))
    }
    func toggleAccountSection(_ section: String, _ accountID: String) {
        let key = accountSectionKey(section, accountID)
        if collapsedAccountSections.contains(key) { collapsedAccountSections.remove(key) }
        else { collapsedAccountSections.insert(key) }
    }

    // MARK: Navigation
    func goToPreviousDay() { selectedDay = CalendarSupport.addingDays(-1, to: selectedDay) }
    func goToNextDay() { selectedDay = CalendarSupport.addingDays(1, to: selectedDay) }
    func goToToday() { selectedDay = CalendarSupport.startOfDay(Date()) }
    func select(day: Date) { selectedDay = CalendarSupport.startOfDay(day) }

    // MARK: Filters
    func toggleAccountVisible(_ id: String) {
        if hiddenAccountIDs.contains(id) { hiddenAccountIDs.remove(id) }
        else { hiddenAccountIDs.insert(id) }
    }
    func toggleListVisible(_ id: String) {
        if hiddenListIDs.contains(id) { hiddenListIDs.remove(id) }
        else { hiddenListIDs.insert(id) }
    }
    func isAccountVisible(_ id: String) -> Bool { !hiddenAccountIDs.contains(id) }

    // MARK: Search (FR-6.4)
    /// Title/notes contains-match across all visible tasks, any day.
    var searchResults: [TaskItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return tasksSnapshot
            .filter { isVisible($0) && !$0.isSubtask }
            .filter { $0.title.lowercased().contains(q) || ($0.notes ?? "").lowercased().contains(q) }
            .sorted(by: taskOrder)
    }

    /// Jump from a search hit to its day (or Inbox → today).
    func reveal(_ task: TaskItem) {
        selectedDay = task.due.map(CalendarSupport.startOfDay) ?? CalendarSupport.startOfDay(Date())
        selectedTaskID = task.id
        searchActive = false
        searchQuery = ""
    }

    // MARK: Keyboard navigation (FR-5.6)
    /// Flat, visible top-level order of the current day view (overdue → day → inbox).
    var keyboardOrder: [String] {
        let c = dayContent
        return (c.overdue + c.today + c.inbox).map(\.id)
    }

    func moveSelection(_ delta: Int) {
        let order = keyboardOrder
        guard !order.isEmpty else { return }
        guard let current = selectedTaskID, let idx = order.firstIndex(of: current) else {
            selectedTaskID = delta > 0 ? order.first : order.last
            return
        }
        let next = min(max(idx + delta, 0), order.count - 1)
        selectedTaskID = order[next]
    }

    // MARK: Per-list incomplete counts (filter panel, design 04)
    func incompleteCount(inList listID: String) -> Int {
        tasksSnapshot.filter { $0.listID == listID && !$0.isCompleted && !$0.isSubtask }.count
    }

    // MARK: Mutations (delegate → reload)
    func toggleComplete(_ id: String) { repo.toggleComplete(id); reload() }
    func deleteTask(_ id: String) { repo.deleteTask(id); reload() }
    func moveToToday(_ id: String) { repo.moveToToday(id); reload() }

    @discardableResult
    func addList(accountID: String, title: String) -> TaskList {
        let list = repo.addList(accountID: accountID, title: title); reload(); return list
    }
    /// Lists belonging to one account, in order.
    func lists(inAccount id: String) -> [TaskList] { listsSnapshot.filter { $0.accountID == id } }
    func renameList(_ id: String, title: String) { repo.renameList(id, title: title); reload() }
    func deleteList(_ id: String) { repo.deleteList(id); reload() }
    func clearCompleted(listID: String) { repo.clearCompleted(listID: listID); reload() }
    /// Clear completed tasks in every visible list (⌘⇧K convenience).
    func clearAllCompleted() {
        for list in listsSnapshot { repo.clearCompleted(listID: list.id) }
        reload()
    }
    func moveTaskToAccount(_ taskID: String, targetListID: String) {
        repo.moveTaskToAccount(taskID, targetListID: targetListID); reload()
    }
    func reorder(_ id: String, after previousID: String?, in listID: String) {
        repo.reorder(id, after: previousID, in: listID); reload()
    }

    /// Drag-drop reorder: drop `draggedID` onto `targetID`. Direction-aware — if the
    /// dragged task was ABOVE the target (dragging down), it lands just AFTER the
    /// target (so dropping on the last card moves it to the very bottom); if it was
    /// below (dragging up), it lands just BEFORE. Order is expressed via Google
    /// `position` (mock rewrites; real backend calls tasks.move).
    /// Drag-drop reorder: drop `draggedID` relative to `targetID`. `after` (from the
    /// drop location — bottom half of the target) lands it just AFTER the target, so
    /// dropping on the last card's lower half moves it to the very bottom; otherwise
    /// just BEFORE. Order is expressed via Google `position` (mock rewrites).
    func dropTask(_ draggedID: String, onto targetID: String, after: Bool) {
        guard draggedID != targetID,
              let target = tasksSnapshot.first(where: { $0.id == targetID }),
              let dragged = tasksSnapshot.first(where: { $0.id == draggedID }) else { return }
        // Reorder is position-based within ONE account. A cross-account move would
        // corrupt the task (list/account mismatch) — that goes through the context
        // menu's recreate+delete path (§8.4.5), not drag-reorder.
        guard dragged.accountID == target.accountID else { return }
        let siblings = tasksSnapshot
            .filter { $0.listID == target.listID && $0.parentID == nil && $0.id != draggedID }
            .sorted { $0.position < $1.position }
        guard let ti = siblings.firstIndex(where: { $0.id == targetID }) else { return }
        let previousID: String? = after
            ? targetID                                   // after the target → moves down
            : (ti > 0 ? siblings[ti - 1].id : nil)       // before the target → moves up
        repo.reorder(draggedID, after: previousID, in: target.listID)
        reload()
    }

    @discardableResult
    func addTask(title: String, listID: String? = nil, due: Date? = nil,
                 notes: String? = nil, parentID: String? = nil) -> TaskItem {
        let target = listID ?? composeTargetListID
        let item = repo.addTask(title: title, listID: target, due: due, notes: notes, parentID: parentID)
        reload()
        return item
    }

    /// Field edit only. A task's account is fixed (`TaskItem.accountID` is `let`), so a
    /// listID belonging to another account would leave account and list disagreeing —
    /// a state the API can't represent (patching account A with account B's tasklist id
    /// just 404s). Cross-account moves are a recreate + delete via `moveTaskToAccount`
    /// (PRD §8.4.5). Guard here so no caller can corrupt the task, whatever the UI does.
    func updateTask(_ task: TaskItem) {
        var task = task
        if let target = list(task.listID), target.accountID != task.accountID {
            assertionFailure("updateTask: cross-account listID — use moveTaskToAccount(_:targetListID:)")
            task.listID = tasksSnapshot.first { $0.id == task.id }?.listID ?? task.listID
        }
        repo.updateTask(task)
        reload()
    }

    func addAccount() async { await repo.addAccount(); reload() }
    func removeAccount(_ id: String) { repo.removeAccount(id); reload() }
    func reauthenticate(_ id: String) async { await repo.reauthenticate(id); reload() }

    func refresh() async {
        await repo.refresh()
        lastSyncedAt = Date()
        reload()
    }

    // MARK: Snapshot sync
    /// Fired after every data change — AppServices hooks dock badge + notifications.
    var onDataChanged: (() -> Void)?

    private func reload() {
        // Only reassign when actually changed — every card reads `store.account(…)`,
        // so blindly reassigning accountsSnapshot on a task toggle would invalidate
        // (re-render) every card even though accounts didn't change.
        let newAccounts = repo.accounts()
        if newAccounts != accountsSnapshot { accountsSnapshot = newAccounts }
        let newLists = repo.lists()
        if newLists != listsSnapshot { listsSnapshot = newLists }
        tasksSnapshot = repo.tasks()
        if listsSnapshot.first(where: { $0.id == composeTargetListID }) == nil {
            composeTargetListID = listsSnapshot.first?.id ?? ""
        }
        refreshDayContent()
        onDataChanged?()
    }
}
