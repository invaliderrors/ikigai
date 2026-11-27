import Foundation
import Testing
@testable import IkigaiCore

struct EditHistoryTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func aDraggedSliderUndoesInOneStep() {
        var history = EditHistory<Int>()
        var value = 0
        for step in 1...50 {  // 50 slider ticks, 20 ms apart
            history.record(before: value, at: start.addingTimeInterval(Double(step) * 0.02))
            value = step
        }
        #expect(history.undo(from: value) == 0)
        #expect(!history.canUndo)
    }

    @Test func separateEditsUndoSeparatelyAndRedoBack() {
        var history = EditHistory<String>()
        history.record(before: "a", at: start)
        history.record(before: "b", at: start.addingTimeInterval(2))
        #expect(history.undo(from: "c") == "b")
        #expect(history.undo(from: "b") == "a")
        #expect(history.redo(from: "a") == "b")
        #expect(history.redo(from: "b") == "c")
        #expect(!history.canRedo)
    }

    @Test func aNewEditClearsRedoAndStartsAFreshStepAfterUndo() {
        var history = EditHistory<Int>()
        history.record(before: 0, at: start)
        _ = history.undo(from: 1)
        #expect(history.canRedo)
        history.record(before: 0, at: start.addingTimeInterval(0.1))  // right after the undo, still a new step
        #expect(!history.canRedo)
        #expect(history.undo(from: 5) == 0)
    }

    @Test func historyIsBounded() {
        var history = EditHistory<Int>(limit: 3)
        for i in 0..<10 { history.record(before: i, at: start.addingTimeInterval(Double(i) * 10)) }
        var undone: [Int] = []
        var current = 10
        while let previous = history.undo(from: current) { undone.append(previous); current = previous }
        #expect(undone == [9, 8, 7])
    }
}
