import AppKit

/// A part of macOS that Unstick can restart.
enum Target: String, CaseIterable {
    /// Also runs Mission Control, Spaces and full-screen switching.
    case dock = "Dock"
    case finder = "Finder"

    var bundleID: String {
        switch self {
        case .dock: return "com.apple.dock"
        case .finder: return "com.apple.finder"
        }
    }
}

/// Restarts the Dock or Finder. macOS relaunches both on its own once they
/// quit; Finder is also reopened here if it doesn't come back.
@MainActor
final class Restarter {
    private var lastWakeTrigger = Date.distantPast

    /// After wake or unlock: wait a few seconds, and restart the Dock at most
    /// once per cooldown, since wake, display wake and unlock often arrive
    /// together.
    func scheduleDockAfterWake(_ reason: String) {
        let since = Date.now.timeIntervalSince(lastWakeTrigger)
        if since < Settings.cooldown {
            Log.write("\(reason): skipped, a Dock restart was already triggered \(Int(since))s ago")
            return
        }
        lastWakeTrigger = Date.now
        let delay = Settings.delay
        Log.write("\(reason): restarting Dock in \(Int(delay))s")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            self.restart(.dock)
        }
    }

    /// Menu item or keyboard shortcut: restart right away, ignoring the
    /// delay and cooldown.
    func restartNow(_ target: Target, _ reason: String) {
        Log.write("\(reason): restarting \(target.rawValue) now")
        restart(target)
    }

    /// Asks the process to quit, then forces it if it is frozen and still
    /// there after 3 seconds.
    private func restart(_ target: Target) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID)
        if running.isEmpty {
            Log.write("\(target.rawValue) wasn't running")
            relaunchIfNeeded(target)
            return
        }
        for app in running {
            kill(app.processIdentifier, SIGTERM)
        }
        Log.write("\(target.rawValue) restarted")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            for app in running where !app.isTerminated {
                kill(app.processIdentifier, SIGKILL)
                Log.write("\(target.rawValue) didn't quit, so it was forced to")
            }
            try? await Task.sleep(for: .seconds(3))
            self.relaunchIfNeeded(target)
        }
    }

    /// The Dock always comes back by itself. Finder normally does too; this
    /// opens it if it hasn't.
    private func relaunchIfNeeded(_ target: Target) {
        guard target == .finder,
              NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID)
        else { return }
        Log.write("opening Finder")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
