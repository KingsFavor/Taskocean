import Foundation

/// A Google Tasks tasklist. Scoped to one account (`tasklists` resource).
struct TaskList: Identifiable, Hashable {
    let id: String
    let accountID: String
    var title: String
    /// Whether this list is currently shown in the merged day view.
    var isVisible: Bool = true
}
