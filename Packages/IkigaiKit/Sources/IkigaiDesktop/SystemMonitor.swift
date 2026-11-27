import AppKit
import IkigaiCore
import IOKit.ps

/// Watches the conditions that pause every screen at once: power source, Low Power Mode, lock and sleep.
@MainActor final class SystemMonitor {
    var onChange: (() -> Void)?
    private(set) var conditions = SystemConditions()
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?

    init() {
        conditions.onBattery = Self.isOnBattery()
        conditions.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Posted on an arbitrary thread; observed on main.
        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) {
            $0.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.asleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.asleep = false }
        observe(workspace, NSWorkspace.willSleepNotification) { $0.asleep = true }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.asleep = false }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, .init("com.apple.screenIsLocked")) { $0.locked = true }
        observe(distributed, .init("com.apple.screenIsUnlocked")) { $0.locked = false }

        let context = Unmanaged.passUnretained(self).toOpaque()
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            // Delivered on the main run loop, where the source is added below.
            MainActor.assumeIsolated {
                let monitor = Unmanaged<SystemMonitor>.fromOpaque(context!).takeUnretainedValue()
                monitor.update { $0.onBattery = SystemMonitor.isOnBattery() }
            }
        }, context)?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
    }

    isolated deinit {
        tokens.forEach { $0.0.removeObserver($0.1) }
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ change: @escaping @Sendable (inout SystemConditions) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.update(change) }
        }
        tokens.append((center, token))
    }

    private func update(_ change: (inout SystemConditions) -> Void) {
        let before = conditions
        change(&conditions)
        if conditions != before { onChange?() }
    }

    static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPMBatteryPowerKey
    }
}
