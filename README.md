# Unstick

A menu bar app that gets stuck parts of macOS working again. It restarts the Dock automatically after your Mac wakes or unlocks, to clear window-management glitches in macOS 27 (Golden Gate), and restarts the Dock or Finder with a keyboard shortcut whenever they get stuck:

- **Control-Option-Command-D** restarts the Dock.
- **Control-Option-Command-F** restarts Finder.

Unstick was called macos-dockwake before version 1.1.

## Install

1. Download the latest **Unstick-….dmg** from the [Releases page](https://github.com/RosBradley/macos-unstick/releases/latest).
2. Open the downloaded file, and drag **Unstick** onto the **Applications** folder.
3. Open **Unstick** from your Applications folder.
4. macOS says it can't check the app for malicious software. Click **Done**.
5. Open **System Settings > Privacy & Security**. Scroll down to the message about Unstick, and click **Open Anyway**. Enter your password if asked.
6. In the welcome message, click **Start at Login**.

Its icon, two circling arrows, then appears in the menu bar at the top right of your screen. You only approve the app once.

**Why macOS warns about it.** Apple only skips that warning for apps signed with a paid Apple Developer account. Unstick isn't, but its full source code is in this repository, and the app is built from it by GitHub, not on someone's own computer. See [Building the app](#building-the-app) for how.

**Coming from macos-dockwake.** Unstick copies macos-dockwake's settings, quits it, and offers to move it to the Trash. Turn on Start at Login again in Unstick's welcome message.

Requires macOS 13 or later, on Apple silicon or Intel.

## Using it

Click the menu bar icon for these options:

| Menu item | What it does |
|---|---|
| Restart Dock | Restarts the Dock right away. Same as pressing Control-Option-Command-D. |
| Restart Finder | Restarts Finder right away. Same as pressing Control-Option-Command-F. |
| Restart Dock After Wake or Unlock | Turns the automatic Dock restart on or off. It starts on. |
| Start at Login | Opens Unstick automatically when you log in. |
| Show Log | Opens the log of wake events and restarts in the Console app. |
| Quit Unstick | Stops it until you open it again. |

The app has no Dock icon. If the menu bar icon is hidden behind the camera notch or other icons, open Unstick from the Applications folder again, and it will tell you it's running.

**If the Dock glitch shows up while you're using the Mac**, press **Control-Option-Command-D**. The Dock restarts at once, without the usual delay. Locking the screen with Control-Command-Q and unlocking it works too.

**If Finder stops responding**, press **Control-Option-Command-F** instead of force quitting it from the Apple menu. Unstick asks Finder to quit, forces it if it's frozen, and reopens it. Finder's windows close and reopen, and a copy or move that Finder was doing stops, so let those finish first if Finder still responds.

The shortcuts work in any app and need no extra permissions.

## The problem

On macOS 27.0.1, the Dock, Mission Control and Spaces can get into a stuck state. The symptoms are:

- **Clicking an open app in the Dock switches to a different app.** A second click usually goes to the right one.
- **Full-screen apps keep the Dock and menu bar drawn over them.** This was seen with Outlook, but any full-screen app can be affected.
- **Three-finger swipes between Spaces stop working**, sometimes only for a while.

This is a known macOS 27 bug, not something wrong with your Mac. As of November 10, 2026:

- macOS 27.0.1 does not fix it.
- There is no macOS 27.1 for Macs.
- macOS 27.2, released October 26, doesn't mention a fix. Its notes cover Siri, Messages and security fixes, and nothing about the Dock, Mission Control, Spaces or full screen.
- Testers reported the bug was still present in the 27.2 betas.
- On our test Mac, 27.2 made the wrong-app Dock clicks less frequent, but they still happen, so the bug isn't fully fixed.
- macOS 27.2.1, released November 9, is a security update. Its notes and press coverage don't mention the Dock, Spaces or full screen.


## Why restarting the Dock helps

The Dock process does much more than show the Dock. It also runs Mission Control, Spaces, full-screen app switching, Cmd-Tab and their trackpad gestures. Restarting it clears the stuck state. macOS relaunches the Dock right away, and your apps and windows are not affected.

The glitches tend to show up after sleep or unlock. macOS gives no signal when the stuck state starts, so Unstick restarts the Dock each time you come back to the Mac.


## How it works

1. Unstick waits in the background for three events: the system waking, the display waking and the screen unlocking.
2. Three seconds after any of them, it restarts the Dock and writes a line to its log.
3. These events often arrive together, so after one restart it ignores further events for 30 seconds. That way the Dock restarts only once per wake.

It uses almost no CPU or memory, since it just waits for events.

The log is at `~/Library/Logs/Unstick.log`. A typical wake looks like this:

```
display wake: restarting Dock in 3s
system wake: skipped, a Dock restart was already triggered 0s ago
screen unlock: skipped, a Dock restart was already triggered 2s ago
Dock restarted
```

**Changing the timings.** There's no menu for these. In Terminal, run one of these, then quit and reopen the app:

```sh
defaults write io.github.rosbradley.unstick Delay -float 5      # seconds to wait after wake
defaults write io.github.rosbradley.unstick Cooldown -float 60  # seconds between automatic restarts
```

## Settings that make the glitches less frequent

None of these fix the bug, but together they reduce how often it happens:

- **Avoid native full screen.** Use Window > Fill instead, or hold Option while hovering over the green window button.
- **Mission Control settings.** In System Settings > Desktop & Dock, turn off "Automatically rearrange Spaces based on most recent use". Turn on "When switching to an application, switch to a Space with open windows for the application".
- **Accessibility settings.** In System Settings > Accessibility > Display, turn on Reduce Transparency and Reduce Motion.
- **Keep the Dock visible.** Turn off "Automatically hide and show the Dock".
- **Trackpad gestures.** In System Settings > Trackpad > More Gestures, set swiping between full-screen apps to three fingers. Turn off Three Finger Drag, which uses the same gesture.


## Limitations

- **It can't tell when the Dock is stuck.** It restarts the Dock after every wake and unlock, whether or not anything was wrong.
- **The Dock blinks for a moment** each time it restarts.
- **It can't fix glitches that start while you're using the Mac.** Press Control-Option-Command-D instead.
- **Finder isn't restarted automatically.** A frozen Finder is rarer and harder to detect, so it's restarted only when you ask.
- **A Dock restart doesn't always clear the Dock over a full-screen app.** Sometimes the Dock disappears for a moment and then comes right back, because the stuck state belongs to the full-screen window, not the Dock. Press Control-Command-F twice to leave and re-enter full screen, or swipe to another Space and back. If it's still there, log out and back in, or restart. Window > Fill avoids it altogether.
- **The unlock event is undocumented.** If a future macOS version stops sending it, the wake events still trigger a restart.

## Troubleshooting

- **There's no Open Anyway button.** It only appears for about an hour after you try to open the app. Open Unstick again, then go back to Privacy & Security.
- **Start at Login doesn't turn on.** Make sure the app is in your Applications folder, not Downloads or the disk image. You can also add it in System Settings > General > Login Items & Extensions, with the + button under Open at Login.
- **A keyboard shortcut does nothing.** Open the menu: an unavailable shortcut is listed under the Restart items, and the log says "keyboard shortcut ... unavailable". That means another app already uses that combination. The menu items still work.
- **The log shows no restarts after wake.** Check that Restart Dock After Wake or Unlock has a check mark.

## Uninstall

1. If Start at Login is on, turn it off in Unstick's menu first, or remove Unstick later in System Settings > General > Login Items & Extensions.
2. Click the menu bar icon and choose **Quit Unstick**.
3. Drag Unstick from Applications to the Trash.

To remove its log too, delete `~/Library/Logs/Unstick.log`.

**When to uninstall.** Once a macOS update fixes the Dock bug, you won't need the automatic restart. macOS 27.2 improves things but doesn't fully fix it, so check the release notes for 27.3 and later.

## Terminal version

The original version, from before the rename, is a script called macos-dockwake.sh with no menu bar icon. It restarts the Dock after wake and unlock and with Control-Option-Command-D, but not Finder. It compiles itself on your Mac and runs as a LaunchAgent. It needs the Xcode Command Line Tools (`xcode-select --install`).

Use either the app or the Terminal version, not both. When Unstick finds the Terminal version, it offers to remove it.

```sh
git clone https://github.com/RosBradley/macos-unstick.git
cd macos-unstick
./macos-dockwake.sh install
```

| Command | What it does |
|---|---|
| `./macos-dockwake.sh install` | Builds and starts the watcher. Running it again rebuilds and restarts it. |
| `./macos-dockwake.sh reset` | Restarts the Dock right now. |
| `./macos-dockwake.sh status` | Shows whether the watcher is running, with its last 10 log lines. |
| `./macos-dockwake.sh uninstall` | Stops the watcher and removes everything it installed. |

To change the timings, pass them to `install`, for example `DELAY=5 COOLDOWN=60 ./macos-dockwake.sh install`.

It installs these files, all in your home folder, with no administrator password:

| Path | Contents |
|---|---|
| `~/Library/LaunchAgents/local.macos-dockwake.plist` | The LaunchAgent that starts the watcher at login |
| `~/Library/Application Support/macos-dockwake/` | The watcher's Swift source and compiled program |
| `~/Library/Logs/macos-dockwake.log` | The log of wake events and Dock restarts |

If you used an earlier version of this tool called spaces-fix, `install` and `uninstall` remove it too.

## Building the app

The app's source code is in `app/Sources`. To build it yourself, with Xcode or the Xcode Command Line Tools installed:

```sh
scripts/build-app.sh
```

That creates `build/Unstick.app`, plus a disk image and a zip.

**Publishing a release.** Push a version tag, and GitHub Actions builds the app and attaches the disk image and zip to a new release:

```sh
git tag v1.1.0
git push origin v1.1.0
```

To test a build without publishing, open the Actions tab, choose Release, and click Run workflow. The files appear under the run's Artifacts.

## License

MIT. See [LICENSE](LICENSE).
