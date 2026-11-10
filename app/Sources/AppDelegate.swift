import AppKit
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// A menu item and its keyboard shortcut, Control+Option+Command+<key>.
    private struct Shortcut {
        let target: Target
        let id: UInt32
        let keyCode: Int
        let key: String
        let item: NSMenuItem
        /// nil until registration is tried.
        var status: OSStatus?
        var description: String { "Control-Option-Command-\(key.uppercased())" }
    }

    private let restarter = Restarter()
    private var statusItem: NSStatusItem?
    private var shortcuts: [Shortcut] = []

    private let shortcutNoteItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let wakeItem = NSMenuItem(
        title: "Restart Dock After Wake or Unlock", action: #selector(AppDelegate.toggleWake),
        keyEquivalent: "")
    private let loginItem = NSMenuItem(
        title: "Start at Login", action: #selector(AppDelegate.toggleLogin), keyEquivalent: "")

    override init() {
        super.init()
        shortcuts = [
            Shortcut(target: .dock, id: 1, keyCode: kVK_ANSI_D, key: "d", item: NSMenuItem(
                title: "Restart Dock", action: #selector(AppDelegate.restartDock), keyEquivalent: "d")),
            Shortcut(target: .finder, id: 2, keyCode: kVK_ANSI_F, key: "f", item: NSMenuItem(
                title: "Restart Finder", action: #selector(AppDelegate.restartFinder), keyEquivalent: "f")),
        ]
    }

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("app started (version \(AppInfo.version))")
        OldApp.copySettings()
        let oldAppWasRunning = OldApp.quitIfRunning()
        setUpMenu()
        registerShortcuts(retries: 3)
        observeWakeAndUnlock()
        if TerminalVersion.isInstalled {
            offerToRemoveTerminalVersion()
        }
        let oldCopies = OldApp.installedCopies
        if !oldCopies.isEmpty {
            offerToRemoveOldApp(oldCopies, wasRunning: oldAppWasRunning)
        }
        if !UserDefaults.standard.bool(forKey: Settings.welcomedKey) {
            UserDefaults.standard.set(true, forKey: Settings.welcomedKey)
            showWelcome()
        }
    }

    /// Opening the app again while it runs shows where it is.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWelcome()
        return false
    }

    // MARK: - Menu

    private func setUpMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(
            systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: AppInfo.name)
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = AppInfo.name

        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "\(AppInfo.name) \(AppInfo.version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        for shortcut in shortcuts {
            shortcut.item.keyEquivalentModifierMask = [.control, .option, .command]
            shortcut.item.target = self
            menu.addItem(shortcut.item)
        }
        shortcutNoteItem.isEnabled = false
        shortcutNoteItem.isHidden = true
        menu.addItem(shortcutNoteItem)
        menu.addItem(.separator())

        wakeItem.target = self
        menu.addItem(wakeItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())

        addItem(to: menu, "Show Log", #selector(AppDelegate.showLog))
        addItem(to: menu, "About \(AppInfo.name)", #selector(AppDelegate.showAbout))
        addItem(to: menu, "Quit \(AppInfo.name)", #selector(AppDelegate.quit), key: "q")

        item.menu = menu
        statusItem = item
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    /// Refreshes check marks each time the menu opens; Start at Login can
    /// change in System Settings while the app runs.
    func menuNeedsUpdate(_ menu: NSMenu) {
        wakeItem.state = Settings.restartAfterWake ? .on : .off
        switch SMAppService.mainApp.status {
        case .enabled: loginItem.state = .on
        case .requiresApproval: loginItem.state = .mixed
        default: loginItem.state = .off
        }
        // A shortcut another app holds isn't shown next to its item.
        var unavailable: [String] = []
        for shortcut in shortcuts {
            let works = shortcut.status == noErr
            shortcut.item.keyEquivalent = works ? shortcut.key : ""
            if !works { unavailable.append("⌃⌥⌘\(shortcut.key.uppercased())") }
        }
        shortcutNoteItem.title = unavailable.count == 1
            ? "Shortcut \(unavailable[0]) unavailable"
            : "Shortcuts \(unavailable.joined(separator: " and ")) unavailable"
        shortcutNoteItem.isHidden = unavailable.isEmpty
    }

    // MARK: - Actions

    @objc private func restartDock() {
        restarter.restartNow(.dock, "menu")
    }

    @objc private func restartFinder() {
        restarter.restartNow(.finder, "menu")
    }

    @objc private func toggleWake() {
        Settings.restartAfterWake.toggle()
        Log.write("restart after wake or unlock turned \(Settings.restartAfterWake ? "on" : "off")")
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                Log.write("start at login turned off")
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                Log.write("start at login turned on")
            }
        } catch {
            Log.write("start at login change failed: \(error.localizedDescription)")
            showAlert(
                "Couldn't change Start at Login",
                "macOS said: \(error.localizedDescription)\n\nYou can add \(AppInfo.name) yourself in System Settings > General > Login Items & Extensions, with the + button under Open at Login.")
        }
    }

    @objc private func showLog() {
        if !FileManager.default.fileExists(atPath: Log.url.path) {
            Log.write("log opened")
        }
        NSWorkspace.shared.open(Log.url)
    }

    @objc private func showAbout() {
        bringToFront()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        Log.write("app quit")
        NSApp.terminate(nil)
    }

    // MARK: - Wake, unlock and the keyboard shortcuts

    private func observeWakeAndUnlock() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.wakeEvent("system wake") }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.wakeEvent("display wake") }
        }
        // Undocumented system notification; if a future macOS stops sending
        // it, the wake notifications above still trigger a restart.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.wakeEvent("screen unlock") }
        }
    }

    private func wakeEvent(_ reason: String) {
        guard Settings.restartAfterWake else { return }
        restarter.scheduleDockAfterWake(reason)
    }

    /// Retries briefly: an old version that was just quit may still be
    /// releasing the Dock shortcut.
    private func registerShortcuts(retries: Int) {
        var failed = false
        for index in shortcuts.indices where shortcuts[index].status != noErr {
            let shortcut = shortcuts[index]
            let target = shortcut.target
            let status = HotKey.register(id: shortcut.id, keyCode: shortcut.keyCode) { [weak self] in
                self?.restarter.restartNow(target, "keyboard shortcut")
            }
            shortcuts[index].status = status
            if status == noErr {
                Log.write("keyboard shortcut \(shortcut.description) ready")
            } else if retries > 0 {
                failed = true
            } else {
                Log.write("keyboard shortcut \(shortcut.description) unavailable (error \(status)); another app may be using it")
            }
        }
        if failed {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self.registerShortcuts(retries: retries - 1)
            }
        }
    }

    // MARK: - Alerts

    private func offerToRemoveTerminalVersion() {
        let alert = NSAlert()
        alert.messageText = "Remove the Terminal version of macos-dockwake?"
        alert.informativeText = "The version installed with macos-dockwake.sh is also on this Mac. With both running, the Dock would restart twice after each wake, and the Dock keyboard shortcut would only work in one of them. \(AppInfo.name) replaces it."
        alert.addButton(withTitle: "Remove It")
        alert.addButton(withTitle: "Keep Both")
        bringToFront()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if TerminalVersion.remove() {
            Log.write("removed the Terminal version")
        } else {
            showAlert(
                "Couldn't remove the Terminal version",
                "In Terminal, go to your macos-dockwake folder and run: ./macos-dockwake.sh uninstall")
        }
    }

    private func offerToRemoveOldApp(_ copies: [URL], wasRunning: Bool) {
        let alert = NSAlert()
        alert.messageText = "Move \(OldApp.name) to the Trash?"
        var text = "\(OldApp.name) is this app's old name, and \(AppInfo.name) replaces it."
        if wasRunning { text += " \(AppInfo.name) has quit it" }
        text += wasRunning ? " and kept its settings." : " \(AppInfo.name) has kept its settings."
        text += "\n\nIf you keep it and it starts at login, both apps would restart the Dock after each wake."
        alert.informativeText = text
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Keep It")
        bringToFront()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if !OldApp.moveToTrash(copies) {
            showAlert(
                "Couldn't move \(OldApp.name) to the Trash",
                "Drag \(OldApp.name) from your Applications folder to the Trash yourself.")
        }
    }

    private func showWelcome() {
        let alert = NSAlert()
        alert.messageText = "\(AppInfo.name) is running"
        let dock = shortcuts[0].description, finder = shortcuts[1].description
        var text = "Its icon is in the menu bar at the top right of your screen.\n\nIt restarts the Dock a few seconds after your Mac wakes or unlocks, which clears the macOS 27 Dock, full-screen and Spaces glitches.\n\nWhen something gets stuck, press \(dock) to restart the Dock, or \(finder) to restart Finder."
        if !AppInfo.isInApplicationsFolder {
            text += "\n\nMove \(AppInfo.name) to your Applications folder before turning on Start at Login."
        }
        alert.informativeText = text
        let startsAtLogin = SMAppService.mainApp.status == .enabled
        if startsAtLogin {
            alert.addButton(withTitle: "OK")
        } else {
            alert.addButton(withTitle: "Start at Login")
            alert.addButton(withTitle: "Not Now")
        }
        bringToFront()
        let response = alert.runModal()
        if !startsAtLogin && response == .alertFirstButtonReturn {
            toggleLogin()
        }
    }

    private func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        bringToFront()
        alert.runModal()
    }

    private func bringToFront() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
