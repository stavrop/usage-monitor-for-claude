# Contributing to Usage Monitor for Claude

Thanks for your interest! This is a small, free, open-source macOS menu bar app.
Bug reports, fixes, and focused features are welcome.

## Ground rules

- **It's an unofficial tool.** The app reads an undocumented Anthropic usage
  endpoint and reuses the public Claude Code OAuth client id. Please keep
  contributions scoped to showing a user *their own* usage. Nothing that scrapes,
  automates at scale, or risks account safety or abuses Anthropic's services.
- **Never log or transmit secrets.** The OAuth token from the Keychain must never
  be printed or sent anywhere but Anthropic's own hosts.
- Be kind in issues and reviews.

## Prerequisites

- macOS 12 (Monterey) or later
- **Xcode Command Line Tools** (`xcode-select --install`) — the app compiles with
  `swiftc`; there is no Xcode project.
- **Claude Code** installed and signed in, so there's a credential to read while
  testing.

## Build & run

The whole app is a single `main.swift` (AppKit).

```sh
./build.sh                 # compiles ClaudeUsage.app in place
open ClaudeUsage.app       # runs it (menu bar only, no Dock icon)
```

While iterating:

```sh
./rebuild-and-restart.sh   # stops the running instance, rebuilds, relaunches
```

## Style & PRs

- Match the surrounding code — it's plain AppKit/Swift, no external dependencies.
  Constants (URLs, thresholds, `DONATION_LINKS`) live near the top of `main.swift`.
- Keep PRs small and single-purpose; describe what changed and why.
- Update `CHANGELOG.md` for user-facing changes.
- Don't commit build output (`ClaudeUsage.app/`, release artifacts).

## Testing your change

Because the app reads and refreshes the Claude Code credential in your Keychain,
test carefully and verify the numbers against what `/usage` shows inside Claude
Code.

## Security issues

Please **do not** open a public issue for a vulnerability — follow
[SECURITY.md](SECURITY.md) (private GitHub advisory).

## License

By contributing, you agree that your contributions are licensed under the
project's [Apache-2.0](LICENSE) license.
