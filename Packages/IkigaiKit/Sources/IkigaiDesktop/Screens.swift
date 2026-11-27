import AppKit

/// A connected display, identified by a UUID that stays the same across reboots and reconnections.
public struct ScreenInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// AppKit global coordinates (origin bottom-left).
    public let frame: CGRect
    public let isBuiltIn: Bool
    let displayID: CGDirectDisplayID
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var info: ScreenInfo? {
        guard let displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let id = CFUUIDCreateString(nil, uuid) as String? else { return nil }
        return ScreenInfo(id: id, name: localizedName, frame: frame,
                          isBuiltIn: CGDisplayIsBuiltin(displayID) != 0, displayID: displayID)
    }
}

enum FullScreen {
    /// True when an ordinary app window covers the whole display: a full-screen app or a zoomed window
    /// that hides the desktop. Window bounds need no Screen Recording permission (window names would).
    static func isCovering(_ display: CGDirectDisplayID) -> Bool {
        let bounds = CGDisplayBounds(display)
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let appWindows = windows.compactMap { info -> CGRect? in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  info[kCGWindowOwnerPID as String] as? pid_t != ProcessInfo.processInfo.processIdentifier,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict) else { return nil }
            return rect
        }
        return covers(display: bounds, windows: appWindows)
    }

    static func covers(display: CGRect, windows: [CGRect]) -> Bool {
        windows.contains { $0.insetBy(dx: -1, dy: -1).contains(display) }
    }
}
