import SwiftUI

/// Add / edit modal (design section 06). Same form for both.
/// The date row uses the same `ComposeDatePill` as the quick-add / footer
/// interfaces, so picking a date works identically everywhere. Date-only per
/// PRD §8.4.1 — the pill has no time affordance at all.
struct TaskEditorView: View {
    let taskID: String
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    /// nil = no date → Inbox. Replaces the old hasDue toggle: the pill's
    /// "없음" option already expresses that state.
    @State private var due: Date?
    @State private var listID = ""
    @State private var subtasks: [TaskItem] = []
    @State private var newSubtask = ""
    @State private var loaded = false
    @State private var pendingSubDelete: TaskItem?

    private var editing: TaskItem? { store.tasksSnapshot.first { $0.id == taskID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("editor.title")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            .padding(.bottom, 14)

            TextField(text: $title) { Text("editor.taskTitle") }
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .padding(10)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 9))

            TextField(text: $notes, axis: .vertical) { Text("editor.notes") }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(2...4)
                .padding(10)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 9))
                .padding(.top, 8)

            // Account · list — same pill as the add interfaces (avatar carries the
            // account, so the "계정 · 리스트" string the Picker needed is redundant).
            HStack(spacing: 10) {
                fieldLabel("editor.list")
                ComposeListPill(listID: $listID, lockedToAccountID: editing?.accountID)
                Spacer()
            }
            .padding(.top, 12)

            // Date — same pill (오늘 / 내일 / 달력 / 없음) as the add interfaces.
            HStack(spacing: 10) {
                fieldLabel("editor.due")
                ComposeDatePill(due: $due)
                Spacer()
            }
            .padding(.top, 10)

            if let editing, editing.parentID == nil {
                subtaskSection
            }

            HStack {
                Spacer()
                Button(role: .cancel) { dismiss() } label: { Text("action.cancel") }
                Button { save() } label: { Text("action.save") }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 18)
        }
        .padding(20)
        .frame(width: 360)
        .background(theme.window)
        .onAppear(perform: loadIfNeeded)
        .confirmationDialog(
            Text("task.delete.confirm"),
            isPresented: Binding(get: { pendingSubDelete != nil },
                                 set: { if !$0 { pendingSubDelete = nil } }),
            presenting: pendingSubDelete
        ) { sub in
            Button(role: .destructive) { removeSub(sub.id) } label: { Text("menu.delete") }
            Button(role: .cancel) {} label: { Text("action.cancel") }
        }
    }

    @ViewBuilder private var subtaskSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("editor.subtasks")
                    .font(.system(size: 11, weight: .bold)).tracking(0.6)
                    .foregroundStyle(theme.textMuted)
                Text("\(subtasks.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textFaint)
            }
            ForEach(subtasks) { sub in
                HStack(spacing: 8) {
                    Checkbox(isCompleted: sub.isCompleted, size: 15) { toggleSub(sub.id) }
                    Text(sub.title)
                        .font(.system(size: 12.5))
                        .foregroundStyle(sub.isCompleted ? theme.textFaint : theme.textSecondary)
                        .strikethrough(sub.isCompleted, color: theme.checkboxRing)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Button { pendingSubDelete = sub } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textFaint).frame(width: 15)
                TextField(text: $newSubtask) { Text("editor.addSubtask") }
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.textSecondary)
                    .onSubmit(addSub)
            }
        }
        .padding(.top, 14)
    }

    private func addSub() {
        let title = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let parent = editing else { return }
        let sub = store.addTask(title: title, listID: parent.listID, due: parent.due, parentID: parent.id)
        subtasks.append(sub)
        newSubtask = ""
    }

    private func toggleSub(_ id: String) {
        store.toggleComplete(id)
        subtasks = store.tasksSnapshot.filter { $0.parentID == editing?.id }
    }

    private func removeSub(_ id: String) {
        store.deleteTask(id)
        subtasks.removeAll { $0.id == id }
    }

    private func fieldLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.textMuted)
            .frame(width: 52, alignment: .leading)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let t = editing {
            title = t.title
            notes = t.notes ?? ""
            due = t.due
            listID = t.listID
            subtasks = store.tasksSnapshot.filter { $0.parentID == t.id }
        } else {
            listID = store.composeTargetListID
            // New task: default date = the day currently being viewed (PRD §6.6 flow).
            due = store.selectedDay
        }
    }

    private func save() {
        if var t = editing {
            t.title = title
            t.notes = notes.isEmpty ? nil : notes
            t.due = due.map(CalendarSupport.startOfDay)
            t.listID = listID
            store.updateTask(t)
        } else if !title.isEmpty {
            store.addTask(title: title, listID: listID, due: due,
                          notes: notes.isEmpty ? nil : notes)
        }
        dismiss()
    }
}
