import Foundation

/// Which wallpaper each screen shows. Screens are keyed by a stable display identifier, so an
/// assignment survives unplugging and comes back when that screen reconnects.
public struct ScreenAssignments: Codable, Hashable, Sendable {
    /// Shown on every screen that has no assignment of its own.
    public private(set) var everywhere: UUID?
    public private(set) var perScreen: [String: UUID] = [:]

    public init() {}

    public func wallpaper(forScreen screenID: String) -> UUID? {
        perScreen[screenID] ?? everywhere
    }

    /// "Show on All Screens": one wallpaper everywhere, replacing per-screen choices.
    public mutating func showEverywhere(_ wallpaper: UUID?) {
        everywhere = wallpaper
        perScreen = [:]
    }

    public mutating func show(_ wallpaper: UUID?, onScreen screenID: String) {
        perScreen[screenID] = wallpaper
    }

    /// Called when a wallpaper leaves the library, so no screen points at a missing package.
    public mutating func remove(_ wallpaper: UUID) {
        if everywhere == wallpaper { everywhere = nil }
        perScreen = perScreen.filter { $0.value != wallpaper }
    }

    /// Drops references to wallpapers that no longer exist (deleted outside the app).
    public mutating func keep(only existing: Set<UUID>) {
        if let everywhere, !existing.contains(everywhere) { self.everywhere = nil }
        perScreen = perScreen.filter { existing.contains($0.value) }
    }
}
