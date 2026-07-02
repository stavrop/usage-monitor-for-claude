# Cutting a release

This project ships a **pre-built, notarized `.app`** as a GitHub Release asset,
and (optionally) a Homebrew cask that points at it.

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

## 3. (Optional) Homebrew

Fastest path — **your own tap**, which has no notability requirement:

1. Create a `homebrew-tap` repo on your GitHub account.
2. Copy [`packaging/usage-monitor-for-claude.rb`](packaging/usage-monitor-for-claude.rb)
   to `Casks/usage-monitor-for-claude.rb` there.
3. Set `version` and `sha256` (from step 1) and commit.
4. Users install with:
   ```sh
   brew tap stavrop/tap
   brew install --cask usage-monitor-for-claude
   ```

Graduating into the **official homebrew-cask** later requires:
- The app is signed + notarized (satisfied by `tools/build_release.sh`).
- The repo meets Homebrew's notability threshold — roughly **75 stars** (or
  comparable forks/watchers). See
  <https://docs.brew.sh/Acceptable-Casks>.
