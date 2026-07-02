# Usage Monitor for Claude

A tiny macOS **menu bar** app that shows your Claude **session** (5-hour) and
**weekly** (7-day) usage as live percentages with reset times — the same numbers
`/usage` shows inside Claude Code — without opening a terminal.

```
⛏ 67% · 4h12m
```

Click the menu bar item for a breakdown (session, weekly-all, weekly per-model)
and each bucket's reset time. It notifies you once per window when a bucket
crosses 90%.

> **Unofficial project — not affiliated with Anthropic.** This is an independent
> utility, not affiliated with, endorsed by, or sponsored by Anthropic. "Claude",
> "Claude Code", and "Anthropic" are trademarks of Anthropic PBC, used here only
> to describe what the software works with. It reads an **undocumented** OAuth
> usage endpoint and reuses the public Claude Code OAuth client id, so it may
> break at any time and could conflict with Anthropic's terms of service. Use it
> **at your own risk**. It authenticates only with the Claude Code login already
> on your Mac and sends it only to Anthropic — no data goes anywhere else.

## Requirements

- macOS 12 (Monterey) or later.
- **Claude Code** installed and signed in (`claude`) — the app reads the login
  credential it stores in your Keychain. No API key or extra token needed.
- Building from source additionally needs the **Xcode Command Line Tools**
  (`xcode-select --install`).

## Install

### Download a release (recommended)

Pre-built binaries live on the **[Releases page](https://github.com/stavrop/usage-monitor-for-claude/releases/latest)**
(the "Releases" section of the repo — a separate tab, not a folder in the file
list). Download `ClaudeUsage.zip` from the latest release, unzip it, and drag
`ClaudeUsage.app` to `/Applications`.

Release builds are signed with a Developer ID and notarized by Apple, so they
open normally — no Gatekeeper override needed.

### Homebrew

```sh
brew tap stavrop/tap
brew install --cask usage-monitor-for-claude
```

### Build from source

```sh
git clone https://github.com/stavrop/usage-monitor-for-claude.git
cd usage-monitor-for-claude
./build.sh            # compiles ClaudeUsage.app with the Command Line Tools
open ClaudeUsage.app
```

When iterating with the app installed as a login item, use
`./rebuild-and-restart.sh` — it stops the running instance before rebuilding, so
macOS doesn't kill the new build for a code-signature mismatch, then relaunches it.

> A source build is **unsigned**. macOS runs a locally-built app fine, but if you
> copy it to another Mac, remove the quarantine flag first:
> `xattr -dr com.apple.quarantine ClaudeUsage.app`. For distributable, notarized
> builds see [RELEASE.md](RELEASE.md).

On first launch macOS asks for permission to read the `Claude Code-credentials`
Keychain item — choose **Always Allow** so it can refresh silently.

- **90% alerts** use `osascript`, so the notification is attributed to *Script
  Editor*. If you don't see alerts, allow notifications for *Script Editor* in
  System Settings → Notifications.

## Launch at login

A LaunchAgent template lives in [`launchd/`](launchd/). Point it at the binary you
just built and load it:

```sh
# Fill in the absolute path to the built binary and install the agent:
APP_BIN="$(pwd)/ClaudeUsage.app/Contents/MacOS/ClaudeUsage"
sed "s#__APP_BINARY_PATH__#${APP_BIN}#" launchd/com.local.claudeusage.plist \
    > ~/Library/LaunchAgents/com.local.claudeusage.plist

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.claudeusage.plist
```

```sh
# disable:  launchctl bootout   gui/$(id -u)/com.local.claudeusage
# restart:  launchctl kickstart -k gui/$(id -u)/com.local.claudeusage
```

> The agent stores an absolute path. If you move or rebuild the app elsewhere,
> regenerate the plist and re-bootstrap.

## How it works

The app reads the OAuth credential Claude Code already stored in your login
Keychain (`Claude Code-credentials`), refreshes the access token when it has
expired, and polls the usage endpoint every 10 minutes (the countdown in the
title ticks locally between polls, so no extra network traffic):

```http
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <oauth-access-token>
anthropic-beta: oauth-2025-04-20
```

Relevant fields: `five_hour` (session) and `seven_day` (weekly), each with a
utilization percentage and `resets_at`; plus a `limits[]` array carrying
per-model scoped weekly buckets.

Nothing is stored except what Claude Code already keeps in your Keychain, and the
token is sent only to Anthropic's own hosts.

## Configuration

Defaults live at the top of [`main.swift`](main.swift):

| Constant           | Default | Meaning                                   |
|--------------------|---------|-------------------------------------------|
| `REFRESH_INTERVAL` | `600`   | Seconds between usage polls (10 min).     |
| `ALERT_THRESHOLD`  | `90`    | Percent at which a bucket notifies once.  |

Edit and re-run `./build.sh` to change them.

## The app icon

The icon is original — a usage-gauge mark drawn from scratch with CoreGraphics
(see [`tools/make_icon.swift`](tools/make_icon.swift)). Regenerate with:

```sh
swift tools/make_icon.swift icon_1024.png
```

## License

[Apache License 2.0](LICENSE) © 2026 Georgios Stavropoulos. See also [NOTICE](NOTICE).
Apache-2.0 is used partly for its explicit trademark clause (§6): the license
grants no rights to the "Claude"/"Anthropic" marks this project refers to.
