# Security Policy

## Supported versions

Only the latest release of Unstick gets fixes. Download it from the [Releases page](https://github.com/RosBradley/macos-unstick/releases/latest).

| Version | Supported |
| ------- | --------- |
| 1.1.x (Unstick) | Yes |
| 1.0.x (macos-dockwake) | No, update to Unstick |
| macos-dockwake.sh (Terminal version) | Best effort |

## Reporting a vulnerability

Please report it privately: open the repository's **Security** tab and click **Report a vulnerability**. Don't open a public issue for a security problem.

Include what you found, the macOS and Unstick versions, and the steps to reproduce it. This is a one-person project, so expect a first reply within about a week. If the report is confirmed, a fixed release follows and the report is credited unless you'd rather stay anonymous. If it's declined, you'll get an explanation.

## What Unstick does

To help judge a report: Unstick runs as your user, without administrator rights. It restarts the Dock and Finder, writes a log to `~/Library/Logs/Unstick.log`, and doesn't use the network. The app isn't signed with a paid Apple developer account, so macOS asks you to approve it once in Privacy & Security.
