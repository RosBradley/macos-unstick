import AppKit

/// The app before it was renamed Unstick: macos-dockwake.app, version 1.0.
/// Running both would restart the Dock twice after each wake, and only one
/// of them could hold Control+Option+Command+D.
enum OldApp {
    static let name = "macos-dockwake"
    private static let bundleID = "io.github.rosbradley.macos-dockwake"
    private static let migratedKey = "MigratedFromDockwake"

    /// Copies the old app's settings once, so Restart After Wake, the delay
    /// and the cooldown carry over.
    static func copySettings() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        guard let old = UserDefaults(suiteName: bundleID) else { return }
        var copied: [String] = []
        for key in [Settings.restartAfterWakeKey, Settings.delayKey, Settings.cooldownKey] {
            if let value = old.object(forKey: key), defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
                copied.append(key)
            }
        }
        if !copied.isEmpty {
            Log.write("copied settings from \(name): \(copied.joined(separator: ", "))")
        }
    }

    /// Quits the old app if it is running. Returns true if it was.
    static func quitIfRunning() -> Bool {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        for app in running { app.terminate() }
        if !running.isEmpty { Log.write("quit \(name)") }
        return !running.isEmpty
    }

    /// Copies of the old app in an Applications folder, which are the ones
    /// worth offering to remove (not one inside a mounted disk image).
    static var installedCopies: [URL] {
        NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID).filter { url in
            let path = url.path
            return path.hasPrefix("/Applications/")
                || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        }
    }

    /// Moves the copies to the Trash. Returns false if any couldn't be moved.
    static func moveToTrash(_ urls: [URL]) -> Bool {
        var ok = true
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                Log.write("moved \(url.path) to the Trash")
            } catch {
                Log.write("couldn't move \(url.path) to the Trash: \(error.localizedDescription)")
                ok = false
            }
        }
        return ok
    }
}

/// The LaunchAgent installed by macos-dockwake.sh, the Terminal version.
/// Running it next to the app would restart the Dock twice and hold the Dock
/// keyboard shortcut.
enum TerminalVersion {
    private static let label = "local.macos-dockwake"
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let plist = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    private static let supportDir = home.appendingPathComponent(
        "Library/Application Support/macos-dockwake")

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plist.path)
    }

    /// Stops the watcher and removes its files. Keeps its log.
    static func remove() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        try? FileManager.default.removeItem(at: plist)
        try? FileManager.default.removeItem(at: supportDir)
        return !isInstalled
    }
}
