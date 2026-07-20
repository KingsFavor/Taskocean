import Foundation

/// A single Google Task. `due` is date-only per API constraint (PRD §8.4.1).
struct TaskItem: Identifiable, Hashable {
    let id: String
    let accountID: String
    /// Mutable: tasks can move between lists (tasks.move destinationTasklist).
    var listID: String

    var title: String
    var notes: String?
    /// Date-only. `nil` means "no due date" → Inbox section (PRD FR-DAY-4).
    /// Stored as a `Date` normalized to noon UTC-agnostic start-of-day (see `DueDate`).
    var due: Date?
    var isCompleted: Bool = false
    var completedAt: Date?

    /// Google `position` string preserves manual ordering within a list.
    var position: String = ""
    /// Parent task id for a subtask (1 level only, PRD §8.4.2). `nil` = top level.
    var parentID: String?

    /// Local sync visualization (PRD FR-SYNC-8). Cosmetic in the mock layer.
    var syncState: SyncState = .synced

    // Convenience -------------------------------------------------------------

    var isSubtask: Bool { parentID != nil }
    var hasNotes: Bool { !(notes ?? "").isEmpty }
}

/// Per-item sync state, shown subtly (a small dot/opacity) — never blocking.
enum SyncState: Hashable {
    case synced
    case pending      // queued in outbox
    case conflict
    case error
}

/// Free-standing metadata used by the day-view grouping engine.
enum DayGroup: Hashable {
    case overdue
    case today
    case inbox
}
