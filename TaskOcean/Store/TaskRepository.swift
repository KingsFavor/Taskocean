import Foundation

/// The single seam between UI and data. The UI depends ONLY on this protocol.
/// Default: `GoogleTasksRepository` (Keychain OAuth + outbox + polling) once a
/// client ID is configured — which it is. `MockTaskRepository` (in-memory) is the
/// fallback when the client ID is empty or `TASKOCEAN_FORCE_MOCK=1`.
///
/// All mutations are expressed as intents; a real backend applies them optimistically
/// and reconciles against the server (PRD §8.3). The mock applies them immediately.
@MainActor
protocol TaskRepository: AnyObject {
    /// Fired when data changes OUTSIDE a store-initiated call (poll merges,
    /// outbox flush completions, session-state flips). Store-initiated mutations
    /// don't need it — AppStore reloads after each call it makes itself.
    var onChange: (() -> Void)? { get set }

    // Snapshot ----------------------------------------------------------------
    func accounts() -> [Account]
    func lists() -> [TaskList]
    func tasks() -> [TaskItem]

    // Account lifecycle -------------------------------------------------------
    func addAccount() async
    func removeAccount(_ id: String)
    func reauthenticate(_ accountID: String) async

    // Task mutations (optimistic) ---------------------------------------------
    @discardableResult
    func addTask(title: String, listID: String, due: Date?, notes: String?, parentID: String?) -> TaskItem
    func updateTask(_ task: TaskItem)
    func toggleComplete(_ id: String)
    func deleteTask(_ id: String)
    func moveToToday(_ id: String)   // Overdue → today (explicit, sets due=today)
    func reorder(_ id: String, after previousID: String?, in listID: String)

    // List mutations ----------------------------------------------------------
    func setListVisible(_ listID: String, _ visible: Bool)
    func setAccountVisible(_ accountID: String, _ visible: Bool)
    @discardableResult
    func addList(accountID: String, title: String) -> TaskList        // tasklists.insert
    func renameList(_ listID: String, title: String)                  // tasklists.patch
    func deleteList(_ listID: String)                                 // tasklists.delete
    func clearCompleted(listID: String)                               // tasks.clear

    /// Cross-account move = recreate in target + delete original (PRD §8.4.5).
    /// Returns the new task id, or nil if the move failed.
    @discardableResult
    func moveTaskToAccount(_ taskID: String, targetListID: String) -> String?

    // Sync (no-op in mock) ----------------------------------------------------
    func refresh() async
}
