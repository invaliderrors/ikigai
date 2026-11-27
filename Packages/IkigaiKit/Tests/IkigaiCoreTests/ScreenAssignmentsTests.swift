import Foundation
import Testing
@testable import IkigaiCore

struct ScreenAssignmentsTests {
    let neon = UUID(), alpine = UUID()

    @Test func perScreenChoiceOverridesEverywhere() {
        var assignments = ScreenAssignments()
        assignments.showEverywhere(neon)
        assignments.show(alpine, onScreen: "studio-display")
        #expect(assignments.wallpaper(forScreen: "built-in") == neon)
        #expect(assignments.wallpaper(forScreen: "studio-display") == alpine)
    }

    @Test func showEverywhereReplacesPerScreenChoices() {
        var assignments = ScreenAssignments()
        assignments.show(alpine, onScreen: "studio-display")
        assignments.showEverywhere(neon)
        #expect(assignments.wallpaper(forScreen: "studio-display") == neon)
    }

    @Test func unpluggedScreensAreRemembered() throws {
        var assignments = ScreenAssignments()
        assignments.show(alpine, onScreen: "dell-portrait")
        let restored = try JSONDecoder().decode(ScreenAssignments.self, from: JSONEncoder().encode(assignments))
        #expect(restored.wallpaper(forScreen: "dell-portrait") == alpine)
    }

    @Test func turningOneScreenOffKeepsEveryOtherChoice() {
        var assignments = ScreenAssignments()
        assignments.showEverywhere(neon)
        assignments.show(alpine, onScreen: "unplugged-dell")
        assignments.turnOff(screen: "built-in", connected: ["built-in", "studio-display"])
        #expect(assignments.wallpaper(forScreen: "built-in") == nil)
        #expect(assignments.wallpaper(forScreen: "studio-display") == neon)
        #expect(assignments.wallpaper(forScreen: "unplugged-dell") == alpine)
    }

    @Test func removedWallpapersLeaveNoDanglingReferences() {
        var assignments = ScreenAssignments()
        assignments.showEverywhere(neon)
        assignments.show(neon, onScreen: "a")
        assignments.show(alpine, onScreen: "b")
        assignments.remove(neon)
        #expect(assignments.wallpaper(forScreen: "a") == nil)
        #expect(assignments.wallpaper(forScreen: "b") == alpine)

        assignments.keep(only: [])
        #expect(assignments == ScreenAssignments())
    }
}
