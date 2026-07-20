import SwiftUI
import UniformTypeIdentifiers

/// Classic reorder drop target. Pairs with `.onDrag` (both are the NSItemProvider
/// API, so they interoperate — mixing `.onDrag` with the newer `.dropDestination`
/// does not). `DropDelegate` is used specifically because it reports the live drop
/// `location`, which is what lets the row draw the insertion line ABOVE vs BELOW
/// itself — the newer `.dropDestination` only exposes a plain `isTargeted` Bool,
/// so "insert after the last card" could never be expressed.
struct ReorderDropDelegate: DropDelegate {
    let targetID: String
    let store: AppStore
    /// Height of the row this delegate is attached to (to split top/bottom half).
    let height: CGFloat
    @Binding var edge: VerticalEdge?

    private var draggedID: String? {
        guard let id = store.draggingID, id != targetID else { return nil }
        return id
    }

    func validateDrop(info: DropInfo) -> Bool { draggedID != nil }

    func dropEntered(info: DropInfo) { update(info) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        update(info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { edge = nil }

    func performDrop(info: DropInfo) -> Bool {
        let after = (edge == .bottom)
        edge = nil
        guard let dragged = draggedID else { return false }
        store.draggingID = nil
        store.dropTask(dragged, onto: targetID, after: after)
        return true
    }

    private func update(_ info: DropInfo) {
        guard draggedID != nil else { edge = nil; return }
        // Lower half → insert after this row (this is how a task moves DOWN and how
        // it reaches the very bottom); upper half → insert before it.
        edge = (height > 0 && info.location.y > height / 2) ? .bottom : .top
    }
}
