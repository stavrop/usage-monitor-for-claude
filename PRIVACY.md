# Privacy Policy

**Usage Monitor for Claude** — last updated 2026-07-29

**Short version: this app has no servers and collects nothing.** Everything happens
on your Mac, and the only service it talks to is Anthropic, reusing the Claude Code
login you already have.

## Scope

This policy covers the Usage Monitor for Claude macOS app ("the app"), distributed
at <https://github.com/stavrop/usage-monitor-for-claude> and via the `stavrop/tap`
Homebrew tap.

## What the app collects

**Nothing — for the developer.** There is no server, no analytics, no telemetry,
no crash reporting, no tracking, and no account with the developer. The developer
never receives your credentials or your usage data. The app runs entirely on your
Mac and communicates **only with Anthropic's servers** to read your usage.

## Credentials it uses

- The app reads the OAuth credential that **Claude Code** already stores in your
  login **Keychain** (item `Claude Code-credentials`). It refreshes the access
  token when it expires and writes the refreshed token back to that same item.
- That token is sent **only to Anthropic's own hosts** (`api.anthropic.com`,
  `platform.claude.com`) to read your usage. It is never sent anywhere else and
  never to the developer.

## Data stored locally on your Mac

- The Claude Code credential lives in your login Keychain and belongs to Claude
  Code; the app reads and refreshes it but keeps no separate copy.
- **App preferences** (macOS user defaults): non-personal settings only, such as
  whether the tip-jar item is hidden.
- Your usage numbers are fetched live from Anthropic and shown in the menu; the app
  keeps no database of them.

## Third parties

- **Anthropic.** Usage data is processed by Anthropic under
  [Anthropic's Privacy Policy](https://www.anthropic.com/legal/privacy). This app
  is not affiliated with Anthropic.
- **Optional links.** If you click a tip-jar link or open the project on GitHub,
  your browser opens that site (e.g. Buy Me a Coffee, GitHub), each with its own
  privacy policy. The app shares no data with them.

## Children

The app is not directed at children and collects no personal information from
anyone.

## Changes

This policy may change; updates are published here with a new "last updated" date.

## Contact

Questions or concerns: open an issue at
<https://github.com/stavrop/usage-monitor-for-claude/issues>.
