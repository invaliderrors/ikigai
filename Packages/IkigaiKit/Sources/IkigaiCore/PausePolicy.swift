/// Why a screen isn't playing. "Intermission" is the product's one word for paused;
/// the reason always travels with it.
public enum Intermission: String, Sendable, CaseIterable {
    case userPaused, asleep, locked, onBattery, lowPowerMode, fullScreen, covered

    public var reason: String {
        switch self {
        case .userPaused: "By you"
        case .asleep: "Display asleep"
        case .locked: "Screen locked"
        case .onBattery: "On battery"
        case .lowPowerMode: "Low Power Mode"
        case .fullScreen: "Full-screen app"
        case .covered: "Covered"
        }
    }
}

/// The user's choices in Settings › Performance. Locked and asleep always pause.
public struct PausePreferences: Codable, Hashable, Sendable {
    public var whenCovered = true
    public var whenFullScreen = true
    public var onBattery = true
    public var inLowPowerMode = true

    public init() {}
}

/// Conditions that apply to every screen at once.
public struct SystemConditions: Hashable, Sendable {
    public var userPaused = false
    public var asleep = false
    public var locked = false
    public var onBattery = false
    public var lowPowerMode = false

    public init() {}
}

/// Conditions for one screen.
public struct ScreenConditions: Hashable, Sendable {
    public var covered = false
    public var fullScreen = false

    public init(covered: Bool = false, fullScreen: Bool = false) {
        self.covered = covered
        self.fullScreen = fullScreen
    }
}

public enum PausePolicy {
    /// The intermission for a screen, or nil when it should play. Reasons are checked in order,
    /// so the one shown to the user is the most fundamental (you paused it beats covered).
    public static func intermission(system: SystemConditions, screen: ScreenConditions,
                                    preferences: PausePreferences) -> Intermission? {
        if system.userPaused { return .userPaused }
        if system.asleep { return .asleep }
        if system.locked { return .locked }
        if system.onBattery && preferences.onBattery { return .onBattery }
        if system.lowPowerMode && preferences.inLowPowerMode { return .lowPowerMode }
        if screen.fullScreen && preferences.whenFullScreen { return .fullScreen }
        if screen.covered && preferences.whenCovered { return .covered }
        return nil
    }
}
