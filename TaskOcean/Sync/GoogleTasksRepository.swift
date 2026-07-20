import AppKit
import Foundation

/// The real backend (PRD §8.3): Google Tasks is the source of truth, local state
/// is a cache. Every mutation applies **optimistically** to the in-memory
/// snapshot, is journaled to a **durable outbox** (survives relaunch), and is
/// flushed to the API in order. Polling pulls server state and merges, with
/// per-account isolation — one dead session never blocks the others (§8.7).
///
/// Swapped in for `MockTaskRepository` by TaskOceanApp when a client ID is set.
@MainActor
final class GoogleTasksRepository: TaskRepository {
    var onChange: (() -> Void)?

    // Snapshots (what the UI reads) --------------------------------------------
    private var _accounts: [Account] = []
    private var _lists: [TaskList] = []
    private var _tasks: [TaskItem] = []

    private var sessions: [String: GoogleAccountSession] = [:]
    private var outbox: [Op] = []
    private var flushing = false
    private var syncing = false
    private var lastPullAt = Date.distantPast
    private var pollTimer: Timer?

    private static let tempPrefix = "local-"
    /// Poll cadence (PRD §8.3 polling-based; kept light per CLAUDE.md §1.5).
    private static let pollInterval: TimeInterval = 90

    // MARK: - Outbox operation

    private struct Op: Codable {
        enum Kind: String, Codable {
            case insertTask, patchTask, deleteTask, moveTask
            case insertList, patchList, deleteList, clearCompleted
        }
        var uid = UUID()
        var kind: Kind
        var accountID: String
        var id: String                 // subject task/list id (may be a temp id)
        var listID: String = ""        // owning list for task ops
        // payload (insert = all set; patch = only flagged fields)
        var title: String?
        var setNotes = false; var notes: String?
        var setDue = false; var due: Date?
        var setStatus = false; var completed = false
        // structure
        var parentID: String?
        var previousID: String?
        var destinationListID: String?
    }

    // MARK: - Init / persistence

    init() {
        loadFromDisk()
        for stored in _accounts {
            if let session = GoogleAccountSession(accountID: stored.id) {
                sessions[stored.id] = session
            } else if let i = _accounts.firstIndex(where: { $0.id == stored.id }) {
                _accounts[i].sessionState = .needsReauth   // keychain blob lost
            }
        }
        startPolling()
        Task { await syncAll() }
    }

    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let d = base.appendingPathComponent("TaskOcean", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private struct StoredAccount: Codable {
        var id: String, email: String, name: String
        var workspace: Bool, color: String
    }
    private struct StoredList: Codable {
        var id: String, accountID: String, title: String, isVisible: Bool
    }
    private struct StoredTask: Codable {
        var id: String, accountID: String, listID: String, title: String
        var notes: String?, due: Date?, isCompleted: Bool, completedAt: Date?
        var position: String, parentID: String?
    }
    private struct Cache: Codable { var lists: [StoredList]; var tasks: [StoredTask] }

    private func loadFromDisk() {
        let dir = Self.dir
        if let data = try? Data(contentsOf: dir.appendingPathComponent("accounts.json")),
           let stored = try? JSONDecoder().decode([StoredAccount].self, from: data) {
            _accounts = stored.map {
                Account(id: $0.id, displayName: $0.name, email: $0.email,
                        kind: $0.workspace ? .workspace : .personal,
                        colorSeed: AccountColor(rawValue: $0.color) ?? .blue)
            }
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("cache.json")),
           let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            _lists = cache.lists.map {
                TaskList(id: $0.id, accountID: $0.accountID, title: $0.title, isVisible: $0.isVisible)
            }
            _tasks = cache.tasks.map {
                TaskItem(id: $0.id, accountID: $0.accountID, listID: $0.listID,
                         title: $0.title, notes: $0.notes, due: $0.due,
                         isCompleted: $0.isCompleted, completedAt: $0.completedAt,
                         position: $0.position, parentID: $0.parentID)
            }
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("outbox.json")),
           let ops = try? JSONDecoder().decode([Op].self, from: data) {
            outbox = ops
        }
        markPending()
    }

    private func persistAccounts() {
        let stored = _accounts.map {
            StoredAccount(id: $0.id, email: $0.email, name: $0.displayName,
                          workspace: $0.kind == .workspace, color: $0.colorSeed.rawValue)
        }
        try? JSONEncoder().encode(stored).write(to: Self.dir.appendingPathComponent("accounts.json"))
    }

    private func persistCache() {
        let cache = Cache(
            lists: _lists.map {
                StoredList(id: $0.id, accountID: $0.accountID, title: $0.title, isVisible: $0.isVisible)
            },
            tasks: _tasks.map {
                StoredTask(id: $0.id, accountID: $0.accountID, listID: $0.listID,
                           title: $0.title, notes: $0.notes, due: $0.due,
                           isCompleted: $0.isCompleted, completedAt: $0.completedAt,
                           position: $0.position, parentID: $0.parentID)
            })
        try? JSONEncoder().encode(cache).write(to: Self.dir.appendingPathComponent("cache.json"))
    }

    private func persistOutbox() {
        try? JSONEncoder().encode(outbox).write(to: Self.dir.appendingPathComponent("outbox.json"))
    }

    // MARK: - TaskRepository: snapshots

    func accounts() -> [Account] { _accounts }
    func lists() -> [TaskList] { _lists }
    func tasks() -> [TaskItem] { _tasks }

    // MARK: - TaskRepository: account lifecycle

    func addAccount() async {
        do {
            let (identity, tokens) = try await GoogleOAuthClient.shared.signIn()
            if let existing = sessions[identity.sub] {
                // Already connected — treat as a re-auth, not a duplicate.
                existing.replace(identity: identity, tokens: tokens)
                setSession(identity.sub, .active)
            } else {
                sessions[identity.sub] = GoogleAccountSession(identity: identity, tokens: tokens)
                let account = Account(
                    id: identity.sub,
                    displayName: identity.name ?? String(identity.email.split(separator: "@").first ?? "?"),
                    email: identity.email,
                    kind: identity.isWorkspace ? .workspace : .personal,
                    colorSeed: AccountColor.seed(forIndex: _accounts.count))
                _accounts.append(account)
                persistAccounts()
            }
            onChange?()
            try await pull(accountID: identity.sub)   // first paint with real data
        } catch OAuthError.cancelled {
            return
        } catch {
            NSLog("TaskOcean addAccount failed: \(error)")
        }
    }

    func removeAccount(_ id: String) {
        sessions[id]?.destroy()
        sessions[id] = nil
        _accounts.removeAll { $0.id == id }
        _lists.removeAll { $0.accountID == id }
        _tasks.removeAll { $0.accountID == id }
        outbox.removeAll { $0.accountID == id }
        persistAccounts(); persistCache(); persistOutbox()
    }

    func reauthenticate(_ accountID: String) async {
        guard let account = _accounts.first(where: { $0.id == accountID }) else { return }
        setSession(accountID, .refreshing); onChange?()
        do {
            let (identity, tokens) = try await GoogleOAuthClient.shared.signIn(loginHint: account.email)
            guard identity.sub == accountID else {
                // User picked a *different* Google account in the chooser — that
                // can't repair this session. Leave the banner up.
                setSession(accountID, .needsReauth); onChange?()
                return
            }
            if let session = sessions[accountID] {
                session.replace(identity: identity, tokens: tokens)
            } else {
                sessions[accountID] = GoogleAccountSession(identity: identity, tokens: tokens)
            }
            setSession(accountID, .active); onChange?()
            await flushAccount(accountID)
            try await pull(accountID: accountID)
        } catch {
            setSession(accountID, .needsReauth); onChange?()
        }
    }

    private func setSession(_ accountID: String, _ state: Account.SessionState) {
        guard let i = _accounts.firstIndex(where: { $0.id == accountID }) else { return }
        _accounts[i].sessionState = state
    }

    // MARK: - TaskRepository: task mutations (optimistic + journaled)

    @discardableResult
    func addTask(title: String, listID: String, due: Date?, notes: String?, parentID: String?) -> TaskItem {
        let accountID = _lists.first { $0.id == listID }?.accountID ?? ""
        let siblings = _tasks
            .filter { $0.listID == listID && $0.parentID == parentID }
            .sorted { $0.position < $1.position }
        // Append at the end, like the mock/UI expects (the API default is
        // insert-at-top, so the op pins `previous` to the current last sibling).
        let position = (siblings.last?.position ?? "") + "1"
        let task = TaskItem(id: Self.tempPrefix + UUID().uuidString,
                            accountID: accountID, listID: listID,
                            title: title, notes: notes,
                            due: due.map(CalendarSupport.startOfDay),
                            isCompleted: false, completedAt: nil,
                            position: position, parentID: parentID,
                            syncState: .pending)
        _tasks.append(task)
        var op = Op(kind: .insertTask, accountID: accountID, id: task.id, listID: listID)
        op.title = title
        op.setNotes = true; op.notes = notes
        op.setDue = true; op.due = task.due
        op.parentID = parentID
        op.previousID = siblings.last?.id
        enqueue(op)
        return task
    }

    func updateTask(_ task: TaskItem) {
        guard let i = _tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let old = _tasks[i]
        var patch = Op(kind: .patchTask, accountID: old.accountID, id: old.id, listID: old.listID)
        var changed = false
        if task.title != old.title { patch.title = task.title; changed = true }
        if task.notes != old.notes { patch.setNotes = true; patch.notes = task.notes; changed = true }
        if task.due != old.due { patch.setDue = true; patch.due = task.due; changed = true }
        if task.isCompleted != old.isCompleted {
            patch.setStatus = true; patch.completed = task.isCompleted; changed = true
        }

        var updated = task
        updated.syncState = .pending
        _tasks[i] = updated
        if changed { enqueue(patch) } else { persistCache() }

        // Same-account list move (cross-account is blocked upstream — AppStore
        // guard + §8.4.5). Children follow: the API moves only the named task.
        if task.listID != old.listID {
            var move = Op(kind: .moveTask, accountID: old.accountID, id: old.id, listID: old.listID)
            move.destinationListID = task.listID
            enqueue(move)
            for j in _tasks.indices where _tasks[j].parentID == old.id {
                let child = _tasks[j]
                _tasks[j].listID = task.listID
                var childMove = Op(kind: .moveTask, accountID: old.accountID,
                                   id: child.id, listID: old.listID)
                childMove.destinationListID = task.listID
                childMove.parentID = old.id
                enqueue(childMove)
            }
        }
    }

    func toggleComplete(_ id: String) {
        guard let i = _tasks.firstIndex(where: { $0.id == id }) else { return }
        _tasks[i].isCompleted.toggle()
        _tasks[i].completedAt = _tasks[i].isCompleted ? Date() : nil
        _tasks[i].syncState = .pending
        var op = Op(kind: .patchTask, accountID: _tasks[i].accountID, id: id, listID: _tasks[i].listID)
        op.setStatus = true; op.completed = _tasks[i].isCompleted
        enqueue(op)
    }

    func deleteTask(_ id: String) {
        guard let task = _tasks.first(where: { $0.id == id }) else { return }
        // Children first: deleting a parent on the server cascades, so the child
        // deletes may 404 — which flush treats as "already done" and drops.
        for child in _tasks.filter({ $0.parentID == id }) {
            enqueue(Op(kind: .deleteTask, accountID: child.accountID,
                       id: child.id, listID: child.listID), flush: false)
        }
        enqueue(Op(kind: .deleteTask, accountID: task.accountID, id: id, listID: task.listID))
        _tasks.removeAll { $0.id == id || $0.parentID == id }
        persistCache()
    }

    func moveToToday(_ id: String) {
        guard let i = _tasks.firstIndex(where: { $0.id == id }) else { return }
        _tasks[i].due = CalendarSupport.startOfDay(Date())
        _tasks[i].syncState = .pending
        var op = Op(kind: .patchTask, accountID: _tasks[i].accountID, id: id, listID: _tasks[i].listID)
        op.setDue = true; op.due = _tasks[i].due
        enqueue(op)
    }

    func reorder(_ id: String, after previousID: String?, in listID: String) {
        guard let task = _tasks.first(where: { $0.id == id }) else { return }
        // Local: dense position rewrite (mirrors the mock, keeps sort stable).
        var siblings = _tasks
            .filter { $0.listID == listID && $0.parentID == nil }
            .sorted { $0.position < $1.position }
        guard let from = siblings.firstIndex(where: { $0.id == id }) else { return }
        let moved = siblings.remove(at: from)
        let insertAt = previousID.flatMap { pid in
            siblings.firstIndex { $0.id == pid }.map { $0 + 1 }
        } ?? 0
        siblings.insert(moved, at: insertAt)
        for (order, sibling) in siblings.enumerated() {
            if let idx = _tasks.firstIndex(where: { $0.id == sibling.id }) {
                _tasks[idx].position = String(format: "%020d", order)
            }
        }
        if let idx = _tasks.firstIndex(where: { $0.id == id }) { _tasks[idx].syncState = .pending }
        var op = Op(kind: .moveTask, accountID: task.accountID, id: id, listID: listID)
        op.previousID = previousID
        enqueue(op)
    }

    // MARK: - TaskRepository: list mutations

    func setListVisible(_ listID: String, _ visible: Bool) {
        guard let i = _lists.firstIndex(where: { $0.id == listID }) else { return }
        _lists[i].isVisible = visible
        persistCache()
    }

    func setAccountVisible(_ accountID: String, _ visible: Bool) {
        // Filtering is view state owned by AppStore (hiddenAccountIDs) — parity with mock.
    }

    @discardableResult
    func addList(accountID: String, title: String) -> TaskList {
        let list = TaskList(id: Self.tempPrefix + UUID().uuidString,
                            accountID: accountID, title: title)
        _lists.append(list)
        var op = Op(kind: .insertList, accountID: accountID, id: list.id)
        op.title = title
        enqueue(op)
        return list
    }

    func renameList(_ listID: String, title: String) {
        guard let i = _lists.firstIndex(where: { $0.id == listID }) else { return }
        _lists[i].title = title
        var op = Op(kind: .patchList, accountID: _lists[i].accountID, id: listID)
        op.title = title
        enqueue(op)
    }

    func deleteList(_ listID: String) {
        guard let list = _lists.first(where: { $0.id == listID }) else { return }
        _lists.removeAll { $0.id == listID }
        _tasks.removeAll { $0.listID == listID }
        // Server delete cascades to the list's tasks — one op is enough.
        outbox.removeAll { $0.listID == listID && $0.kind != .deleteList }
        enqueue(Op(kind: .deleteList, accountID: list.accountID, id: listID))
    }

    func clearCompleted(listID: String) {
        guard let list = _lists.first(where: { $0.id == listID }) else { return }
        _tasks.removeAll { $0.listID == listID && $0.isCompleted }
        enqueue(Op(kind: .clearCompleted, accountID: list.accountID, id: listID, listID: listID))
    }

    @discardableResult
    func moveTaskToAccount(_ taskID: String, targetListID: String) -> String? {
        guard let task = _tasks.first(where: { $0.id == taskID }),
              let targetList = _lists.first(where: { $0.id == targetListID }),
              targetList.accountID != task.accountID else { return nil }
        // Recreate in the target account, then delete the original (§8.4.5) —
        // both legs ride the normal optimistic + outbox path.
        let newTask = addTask(title: task.title, listID: targetListID,
                              due: task.due, notes: task.notes, parentID: nil)
        for sub in _tasks.filter({ $0.parentID == taskID }) {
            _ = addTask(title: sub.title, listID: targetListID,
                        due: sub.due, notes: sub.notes, parentID: newTask.id)
        }
        deleteTask(taskID)
        return newTask.id
    }

    // MARK: - Sync

    func refresh() async { await syncAll() }

    private func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { _ in
            Task { @MainActor [weak self] in await self?.syncAll() }
        }
        timer.tolerance = Self.pollInterval / 6
        pollTimer = timer

        // Catch up right when the user comes back — the moment staleness shows.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, Date().timeIntervalSince(self.lastPullAt) > 30 else { return }
                await self.syncAll()
            }
        }
    }

    private func syncAll() async {
        guard !syncing, !_accounts.isEmpty else { return }
        syncing = true
        defer { syncing = false }
        // Sequential per account, isolated: one account's failure only skips itself.
        for account in _accounts where account.sessionState != .needsReauth {
            await flushAccount(account.id)
            do { try await pull(accountID: account.id) }
            catch { NSLog("TaskOcean pull(\(account.email)) failed: \(error)") }
        }
        lastPullAt = Date()
    }

    /// Server → local merge for one account. Server wins, except items with
    /// queued ops (their local, newer state is preserved until the op flushes).
    private func pull(accountID: String) async throws {
        let gLists = try await call(accountID) { try await $0.taskLists() }
        var serverLists: [TaskList] = []
        var serverTasks: [TaskItem] = []
        for gList in gLists {
            let visible = _lists.first { $0.id == gList.id }?.isVisible ?? true
            serverLists.append(TaskList(id: gList.id, accountID: accountID,
                                        title: gList.title ?? "", isVisible: visible))
            let gTasks = try await call(accountID) { try await $0.tasks(in: gList.id) }
            for g in gTasks where g.deleted != true && g.hidden != true {
                serverTasks.append(TaskItem(
                    id: g.id, accountID: accountID, listID: gList.id,
                    title: g.title ?? "", notes: g.notes,
                    due: g.due.flatMap(GoogleDates.dueDate),
                    isCompleted: g.status == "completed",
                    completedAt: g.completed.flatMap(GoogleDates.timestamp),
                    position: g.position ?? "", parentID: g.parent))
            }
        }

        let pending = Set(outbox.filter { $0.accountID == accountID }.map(\.id))
        let deletePending = Set(outbox.filter { $0.accountID == accountID && $0.kind == .deleteTask }.map(\.id))

        var mergedLists = serverLists.filter { !pending.contains($0.id) }
        mergedLists += _lists.filter { $0.accountID == accountID && pending.contains($0.id) }
        _lists = _lists.filter { $0.accountID != accountID } + mergedLists

        var mergedTasks = serverTasks.filter { !pending.contains($0.id) && !deletePending.contains($0.id) }
        mergedTasks += _tasks.filter { $0.accountID == accountID && pending.contains($0.id) }
        _tasks = _tasks.filter { $0.accountID != accountID } + mergedTasks

        markPending()
        persistCache()
        onChange?()
    }

    /// Marks snapshot items referenced by queued ops so the UI can show the
    /// quiet pending dot (FR-SYNC-8).
    private func markPending() {
        let pending = Set(outbox.map(\.id))
        for i in _tasks.indices {
            _tasks[i].syncState = pending.contains(_tasks[i].id) ? .pending : .synced
        }
    }

    // MARK: - Outbox flush

    private func enqueue(_ op: Op, flush: Bool = true) {
        outbox.append(op)
        persistOutbox()
        persistCache()
        markPending()
        if flush { Task { await flushAll() } }
    }

    private func flushAll() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }
        for account in _accounts where account.sessionState != .needsReauth {
            await flushAccount(account.id)
        }
    }

    /// Drains one account's ops in order. Transient/auth failures stop this
    /// account (ops stay queued for the next cycle); permanent 4xx drops the op.
    private func flushAccount(_ accountID: String) async {
        while let op = outbox.first(where: { $0.accountID == accountID }) {
            do {
                try await perform(op)
                outbox.removeAll { $0.uid == op.uid }
                persistOutbox()
            } catch let error as APIError {
                switch error {
                case .permanent(let status, let body):
                    NSLog("TaskOcean op dropped (\(status)): \(op.kind) \(body.prefix(200))")
                    outbox.removeAll { $0.uid == op.uid }
                    persistOutbox()
                case .unauthorized:
                    setSession(accountID, .needsReauth); onChange?()
                    return
                case .transient:
                    return
                }
            } catch {
                return   // OAuth/network hiccup — retry next cycle
            }
        }
        markPending()
        persistCache()
        onChange?()
    }

    private func perform(_ op: Op) async throws {
        switch op.kind {
        case .insertTask:
            var body: [String: Any] = ["title": op.title ?? ""]
            if let notes = op.notes { body["notes"] = notes }
            if let due = op.due { body["due"] = GoogleDates.dueString(from: due) }
            let created = try await call(op.accountID) {
                try await $0.insertTask(listID: op.listID, body: body,
                                        parent: op.parentID, previous: op.previousID)
            }
            remapTemp(op.id, to: created.id, serverPosition: created.position)

        case .patchTask:
            var body: [String: Any] = [:]
            if let title = op.title { body["title"] = title }
            if op.setNotes { body["notes"] = op.notes ?? NSNull() }
            if op.setDue { body["due"] = op.due.map(GoogleDates.dueString) ?? NSNull() }
            if op.setStatus {
                body["status"] = op.completed ? "completed" : "needsAction"
                if !op.completed { body["completed"] = NSNull() }
            }
            guard !body.isEmpty else { return }
            _ = try await call(op.accountID) {
                try await $0.patchTask(listID: op.listID, taskID: op.id, body: body)
            }

        case .deleteTask:
            do {
                try await call(op.accountID) {
                    try await $0.deleteTask(listID: op.listID, taskID: op.id)
                }
            } catch APIError.permanent(404, _) {
                // Parent delete already cascaded — done is done.
            }

        case .moveTask:
            let moved = try await call(op.accountID) {
                try await $0.moveTask(listID: op.listID, taskID: op.id,
                                      parent: op.parentID, previous: op.previousID,
                                      destinationList: op.destinationListID)
            }
            if let i = _tasks.firstIndex(where: { $0.id == op.id }),
               let position = moved.position {
                _tasks[i].position = position
            }

        case .insertList:
            let created = try await call(op.accountID) {
                try await $0.insertTaskList(title: op.title ?? "")
            }
            remapTemp(op.id, to: created.id, serverPosition: nil)

        case .patchList:
            try await call(op.accountID) {
                try await $0.patchTaskList(op.id, title: op.title ?? "")
            }

        case .deleteList:
            try await call(op.accountID) { try await $0.deleteTaskList(op.id) }

        case .clearCompleted:
            try await call(op.accountID) { try await $0.clearCompleted(listID: op.id) }
        }
    }

    /// An optimistic insert came back with its server id: rewrite every
    /// reference — snapshots AND queued ops (patches on a temp id must land on
    /// the real one).
    private func remapTemp(_ tempID: String, to serverID: String, serverPosition: String?) {
        for i in _tasks.indices {
            if _tasks[i].id == tempID {
                var t = _tasks[i]
                _tasks[i] = TaskItem(id: serverID, accountID: t.accountID,
                                     listID: t.listID == tempID ? serverID : t.listID,
                                     title: t.title, notes: t.notes, due: t.due,
                                     isCompleted: t.isCompleted, completedAt: t.completedAt,
                                     position: serverPosition ?? t.position,
                                     parentID: t.parentID, syncState: t.syncState)
            }
            if _tasks[i].parentID == tempID { _tasks[i].parentID = serverID }
            if _tasks[i].listID == tempID { _tasks[i].listID = serverID }
        }
        for i in _lists.indices where _lists[i].id == tempID {
            let l = _lists[i]
            _lists[i] = TaskList(id: serverID, accountID: l.accountID,
                                 title: l.title, isVisible: l.isVisible)
        }
        for i in outbox.indices {
            if outbox[i].id == tempID { outbox[i].id = serverID }
            if outbox[i].listID == tempID { outbox[i].listID = serverID }
            if outbox[i].parentID == tempID { outbox[i].parentID = serverID }
            if outbox[i].previousID == tempID { outbox[i].previousID = serverID }
            if outbox[i].destinationListID == tempID { outbox[i].destinationListID = serverID }
        }
        persistOutbox()
        persistCache()
        onChange?()
    }

    // MARK: - Authenticated call with one refresh-retry

    private func call<T>(_ accountID: String,
                         _ body: (GoogleTasksAPI) async throws -> T) async throws -> T {
        guard let session = sessions[accountID] else { throw APIError.unauthorized }
        do {
            return try await body(GoogleTasksAPI(accessToken: session.validToken()))
        } catch APIError.unauthorized {
            _ = try await session.forceRefresh()   // token revoked mid-lifetime?
            return try await body(GoogleTasksAPI(accessToken: session.validToken()))
        } catch let error as OAuthError {
            if error == .invalidGrant {
                setSession(accountID, .needsReauth); onChange?()
                throw APIError.unauthorized
            }
            throw APIError.transient(0)
        }
    }
}
