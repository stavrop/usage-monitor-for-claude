# Cutting a release

This project ships a **pre-built, notarized `.app`** as a GitHub Release asset,
and a Homebrew cask (in the [`stavrop/homebrew-tap`](https://github.com/stavrop/homebrew-tap)
repo) that points at it.

## On every release (checklist)

1. Bump `MARKETING_VERSION` in `main.swift`'s `Info.plist` block (`build.sh`) and
   add a `CHANGELOG.md` entry.
2. **§1** — `tools/build_release.sh` → notarized `ClaudeUsage.zip` + its `sha256`.
3. **§2** — tag `vX.Y.Z`, push, and `gh release create` with the zip.
4. **§3** — bump `version` + `sha256` in the tap's cask and push. **Don't skip
   this** — until the tap is updated, `brew upgrade` won't see the new version.

## 1. Build a notarized zip

One-time setup: a paid Apple Developer account, a *Developer ID Application*
certificate, and notarization credentials (a `notarytool` keychain profile or an
App Store Connect API key). See the header of
[`tools/build_release.sh`](tools/build_release.sh).

```sh
export DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE=umfc-notary        # or ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH
tools/build_release.sh
```

This produces `ClaudeUsage.zip` (notarized + stapled) and prints its **sha256**.

## 2. Tag and publish the GitHub Release

```sh
git tag v0.1.0
git push origin v0.1.0
```

Create a Release for the tag (GitHub UI or `gh release create v0.1.0 ClaudeUsage.zip`)
and attach `ClaudeUsage.zip`. Copy the release notes from
[`CHANGELOG.md`](CHANGELOG.md).

Because the app is notarized and stapled, it opens on a downloader's Mac without
Gatekeeper warnings and without needing `xattr` tricks.

## 3. Bump the Homebrew tap

The tap already exists at [`stavrop/homebrew-tap`](https://github.com/stavrop/homebrew-tap)
(cask: `Casks/usage-monitor-for-claude.rb`). On each release, point it at the new
build:

```sh
cd path/to/homebrew-tap
# edit Casks/usage-monitor-for-claude.rb:
#   - version "X.Y.Z"
#   - sha256 "<the sha256 printed by build_release.sh in §1>"
git commit -am "usage-monitor-for-claude X.Y.Z" && git push
```

`version` also rewrites the release-asset URL (it interpolates `#{version}`), so
those two lines are the only edits. Verify before relying on it:

```sh
brew update
brew fetch --cask stavrop/tap/usage-monitor-for-claude   # re-downloads, checks sha256
brew audit  --cask stavrop/tap/usage-monitor-for-claude   # style/validity
```

Users then get it with `brew upgrade --cask usage-monitor-for-claude`. Keep
[`packaging/usage-monitor-for-claude.rb`](packaging/usage-monitor-for-claude.rb)
in this repo in sync as the canonical template.

### Graduating to official homebrew-cask (later)

- The app is already signed + notarized (satisfied by `tools/build_release.sh`).
- The repo must meet Homebrew's notability threshold — roughly **75 stars** (or
  comparable forks/watchers). See <https://docs.brew.sh/Acceptable-Casks>.
