# Security Policy

## Reporting a vulnerability

Please report security issues privately using GitHub's
[**Report a vulnerability**](https://github.com/stavrop/usage-monitor-for-claude/security/advisories/new)
(Security → Advisories). Please do **not** open a public issue for a
vulnerability until it has been addressed.

I'll acknowledge reports within a few days on a best-effort basis (this is a
hobby project, not a commercial product).

## What this app touches

- It reads the OAuth credential that **Claude Code** already stores in your
  login Keychain (item `Claude Code-credentials`), refreshes the access token
  when it expires, and writes the refreshed token back to that same item.
- It sends that token **only** to Anthropic's own hosts
  (`api.anthropic.com`, `platform.claude.com`) to read your usage.
- It stores nothing else and contains no telemetry, analytics, or third-party
  network calls.

## Trust & scope notes

- The bundled OAuth client id is the **public** Claude Code client id; it is not
  a secret and grants nothing on its own.
- The usage endpoint it calls is **undocumented** and may change or disappear
  without notice. This is an unofficial tool — see the README disclaimer.
- Because it can read and rewrite the Claude Code credential, only run builds you
  trust. Building from source (the documented path) lets you audit exactly what
  runs.
