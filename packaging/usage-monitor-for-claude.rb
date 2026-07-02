# Homebrew cask template for "Usage Monitor for Claude".
#
# For your own tap (no notability requirement — works from day one):
#   1. Create a repo named `homebrew-tap` on your GitHub account.
#   2. Put this file at `Casks/usage-monitor-for-claude.rb` in that repo.
#   3. Fill in `version` and `sha256` from a release built by
#      `tools/build_release.sh` (it prints the sha256).
#   4. Users install with:
#        brew tap stavrop/tap
#        brew install --cask usage-monitor-for-claude
#
# To later graduate into the official homebrew-cask, the app must be signed +
# notarized (it is, via build_release.sh) and the repo must meet Homebrew's
# notability threshold — roughly 75 stars (or comparable forks/watchers). See
# https://docs.brew.sh/Acceptable-Casks#rejected-casks
cask "usage-monitor-for-claude" do
  version "0.1.0"
  sha256 "REPLACE_WITH_ZIP_SHA256"

  url "https://github.com/stavrop/usage-monitor-for-claude/releases/download/v#{version}/ClaudeUsage.zip"
  name "Usage Monitor for Claude"
  desc "Menu bar app showing Claude session and weekly usage"
  homepage "https://github.com/stavrop/usage-monitor-for-claude"

  depends_on macos: ">= :monterey"

  app "ClaudeUsage.app"

  zap trash: [
    "~/Library/Caches/com.local.claudeusage",
    "~/Library/HTTPStorages/com.local.claudeusage",
  ]
end
