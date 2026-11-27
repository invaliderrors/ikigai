import Foundation

/// Undo and redo for a document edited by value. Edits that arrive close together (a slider being
/// dragged) coalesce into one step, so one ⌘Z takes back the whole gesture rather than its last pixel.
public struct EditHistory<State: Equatable & Sendable>: Sendable {
    public let coalescingWindow: TimeInterval
    public let limit: Int
    private var undoStack: [State] = []
    private var redoStack: [State] = []
    private var lastEdit = Date.distantPast

    public init(coalescingWindow: TimeInterval = 0.6, limit: Int = 100) {
        self.coalescingWindow = coalescingWindow
        self.limit = limit
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Call with the state *before* an edit. Starts a new undo step unless the previous edit was moments ago.
    public mutating func record(before state: State, at time: Date = Date()) {
        if time.timeIntervalSince(lastEdit) > coalescingWindow || undoStack.isEmpty {
            undoStack.append(state)
            if undoStack.count > limit { undoStack.removeFirst() }
        }
        redoStack.removeAll()
        lastEdit = time
    }

    /// The state to go back to, given the current one; nil when there's nothing to undo.
    public mutating func undo(from current: State) -> State? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        lastEdit = .distantPast  // the next edit starts a fresh step
        return previous
    }

    public mutating func redo(from current: State) -> State? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        lastEdit = .distantPast
        return next
    }
}
