# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/stavrop/usage-monitor-for-claude/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/stavrop/usage-monitor-for-claude/releases/tag/v0.1.0
