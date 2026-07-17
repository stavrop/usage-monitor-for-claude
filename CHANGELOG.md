# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-07-17

### Fixed
- **Rate-limit (HTTP 429) resilience.** The usage endpoint sits behind an edge
  rate limiter that returns `429` with a `Retry-After` hint. The app now parses
  `Retry-After` (seconds or HTTP-date), keeps the last-good numbers on screen,
  and schedules a single backoff retry that waits **at least** as long as the
  server asks — so it no longer polls back into an open window and keeps it
  armed. Without a server hint it falls back to exponential backoff (30s → 30m
  cap) with jitter to decorrelate from other clients on the same account. A
  successful fetch clears the backoff. Previously any non-2xx just showed
  "Last refresh failed" until the next 10-minute poll, with no `Retry-After`
  handling.

## [0.2.0] - 2026-07-14

### Added
- **Colored gradient usage bars** in the dropdown. Each bucket (session,
  weekly-all, per-model weekly) now renders as a rounded progress bar that ramps
  green → amber → red with severity, instead of a plain text percentage row.
- **Pay-as-you-go credit balance.** A **Credits (monthly)** row shows what you've
  used, what's remaining, and the monthly cap in dollars, behind the same
  severity-colored bar. Parsed from the usage endpoint's `spend` block (with a
  fallback to the legacy `extra_usage` field). The API exposes no reset timestamp
  for credits, so the row is labeled monthly rather than showing a countdown.

## [0.1.0] - 2026-07-02

### Added
- Initial public release of the macOS menu bar app.
- Live **session** (5-hour) and **weekly** (7-day) usage in the menu bar with a
  local countdown to the next reset.
- Dropdown breakdown: session, weekly-all, and per-model scoped weekly buckets
  with reset times.
- One-time-per-window notification when a bucket crosses 90%.
- Skippable "support this app" tip jar shown on launch (opens donation links in
  the browser); reopenable from the menu and dismissible with "Don't show again".
- Reads the Claude Code login credential from the Keychain and refreshes the
  OAuth token silently when it expires.
- `build.sh` (Command Line Tools build), `tools/build_release.sh` (Developer ID
  sign + notarize + staple), launch-at-login template, and an original
  CoreGraphics app icon.

[Unreleased]: https://github.com/stavrop/usage-monitor-for-claude/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/stavrop/usage-monitor-for-claude/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/stavrop/usage-monitor-for-claude/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/stavrop/usage-monitor-for-claude/releases/tag/v0.1.0
