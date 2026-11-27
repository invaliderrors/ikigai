import Testing
@testable import IkigaiCore

struct PausePolicyTests {
    func pause(_ edit: (inout SystemConditions) -> Void = { _ in },
               screen: ScreenConditions = .init(),
               preferences: PausePreferences = .init()) -> Intermission? {
        var system = SystemConditions()
        edit(&system)
        return PausePolicy.intermission(system: system, screen: screen, preferences: preferences)
    }

    @Test func playsWhenNothingStandsInTheWay() {
        #expect(pause() == nil)
    }

    @Test func lockedAndAsleepAlwaysPause() {
        var off = PausePreferences()
        off.whenCovered = false; off.whenFullScreen = false; off.onBattery = false; off.inLowPowerMode = false
        #expect(pause({ $0.locked = true }, preferences: off) == .locked)
        #expect(pause({ $0.asleep = true }, preferences: off) == .asleep)
    }

    @Test func preferencesCanAllowPlaying() {
        var allow = PausePreferences()
        allow.onBattery = false
        allow.whenCovered = false
        #expect(pause({ $0.onBattery = true }, preferences: allow) == nil)
        #expect(pause(screen: .init(covered: true), preferences: allow) == nil)
        #expect(pause(screen: .init(fullScreen: true), preferences: allow) == .fullScreen)
    }

    @Test func theMostFundamentalReasonWins() {
        #expect(pause({ $0.userPaused = true; $0.onBattery = true }, screen: .init(covered: true)) == .userPaused)
        #expect(pause({ $0.onBattery = true }, screen: .init(covered: true, fullScreen: true)) == .onBattery)
        #expect(pause(screen: .init(covered: true, fullScreen: true)) == .fullScreen)
    }

    @Test(arguments: Intermission.allCases)
    func everyIntermissionHasAReason(_ intermission: Intermission) {
        #expect(!intermission.reason.isEmpty)
    }
}
