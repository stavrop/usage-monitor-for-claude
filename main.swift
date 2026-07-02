import AppKit
import Foundation

// MARK: - Config

let KEYCHAIN_SERVICE = "Claude Code-credentials"
let KEYCHAIN_ACCOUNT = NSUserName()
let USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
let TOKEN_URL = "https://platform.claude.com/v1/oauth/token"
// Public Claude Code OAuth client id.
let OAUTH_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
let REFRESH_INTERVAL: TimeInterval = 600   // 10 min; keep polling light to avoid rate limits (usage windows are 5h/7d)
let ALERT_THRESHOLD = 90      // notify when a bucket reaches this %

// MARK: - Models

struct Limit {
    let percent: Int
    let resetsAt: Date?
}

struct Usage {
    let session: Limit?
    let weeklyAll: Limit?
    let weeklyScoped: Limit?      // e.g. Sonnet/Opus scoped weekly
    let scopedName: String?
}

// MARK: - Credentials (Keychain)

struct Credentials: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Double?        // epoch millis
    var scopes: [String]?
    var subscriptionType: String?
    var rateLimitTier: String?

    enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresAt, scopes, subscriptionType, rateLimitTier
    }

    var isExpired: Bool {
        guard let e = expiresAt else { return false }
        return Date().timeIntervalSince1970 * 1000 >= (e - 60_000) // 60s slack
    }
}

enum CredError: Error { case notFound, badFormat }

func runProcess(_ launchPath: String, _ args: [String], stdin: String? = nil) -> (Int32, String, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: launchPath)
    p.arguments = args
    let out = Pipe(); let err = Pipe()
    p.standardOutput = out; p.standardError = err
    if let stdin = stdin {
        let inPipe = Pipe()
        p.standardInput = inPipe
        try? p.run()
        inPipe.fileHandleForWriting.write(stdin.data(using: .utf8)!)
        inPipe.fileHandleForWriting.closeFile()
    } else {
        try? p.run()
    }
    let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    p.waitUntilExit()
    return (p.terminationStatus, o, e)
}

func readCredentials() throws -> Credentials {
    let (code, out, _) = runProcess("/usr/bin/security",
        ["find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT, "-w"])
    guard code == 0 else { throw CredError.notFound }
    let json = out.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = json.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let oauth = obj["claudeAiOauth"] as? [String: Any],
          let credData = try? JSONSerialization.data(withJSONObject: oauth),
          let creds = try? JSONDecoder().decode(Credentials.self, from: credData)
    else { throw CredError.badFormat }
    return creds
}

func writeCredentials(_ creds: Credentials) {
    // Preserve the same wrapper shape Claude Code uses.
    var oauth: [String: Any] = [
        "accessToken": creds.accessToken,
    ]
    if let r = creds.refreshToken { oauth["refreshToken"] = r }
    if let e = creds.expiresAt { oauth["expiresAt"] = e }
    if let s = creds.scopes { oauth["scopes"] = s }
    if let s = creds.subscriptionType { oauth["subscriptionType"] = s }
    if let t = creds.rateLimitTier { oauth["rateLimitTier"] = t }
    let wrapper: [String: Any] = ["claudeAiOauth": oauth]
    guard let data = try? JSONSerialization.data(withJSONObject: wrapper),
          let str = String(data: data, encoding: .utf8) else { return }
    // -U updates if exists. Keep label/account/service identical to Claude Code's item.
    _ = runProcess("/usr/bin/security",
        ["add-generic-password", "-U", "-s", KEYCHAIN_SERVICE, "-a", KEYCHAIN_ACCOUNT,
         "-l", KEYCHAIN_SERVICE, "-w", str])
}

// MARK: - Token refresh

func refreshToken(_ creds: Credentials, completion: @escaping (Credentials?) -> Void) {
    guard let refresh = creds.refreshToken else { completion(nil); return }
    var req = URLRequest(url: URL(string: TOKEN_URL)!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
        "grant_type": "refresh_token",
        "refresh_token": refresh,
        "client_id": OAUTH_CLIENT_ID,
    ]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: req) { data, resp, _ in
        guard let data = data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String else {
            completion(nil); return
        }
        var updated = creds
        updated.accessToken = access
        if let r = obj["refresh_token"] as? String { updated.refreshToken = r }
        if let exp = obj["expires_in"] as? Double {
            updated.expiresAt = Date().timeIntervalSince1970 * 1000 + exp * 1000
        }
        writeCredentials(updated)
        completion(updated)
    }.resume()
}

// MARK: - Usage fetch

let iso = ISO8601DateFormatter()
let isoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

func parseDate(_ s: Any?) -> Date? {
    guard let s = s as? String else { return nil }
    return isoFrac.date(from: s) ?? iso.date(from: s)
}

func parseLimit(_ d: [String: Any]?) -> Limit? {
    guard let d = d else { return nil }
    let pct = (d["percent"] as? NSNumber)?.intValue
        ?? (d["utilization"] as? NSNumber)?.intValue
    guard let p = pct else { return nil }
    return Limit(percent: p, resetsAt: parseDate(d["resets_at"]))
}

func fetchUsage(token: String, completion: @escaping (Result<Usage, Error>) -> Void) {
    var req = URLRequest(url: URL(string: USAGE_URL)!)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    URLSession.shared.dataTask(with: req) { data, resp, err in
        if let err = err { completion(.failure(err)); return }
        guard let http = resp as? HTTPURLResponse else {
            completion(.failure(CredError.badFormat)); return
        }
        if http.statusCode == 401 {
            completion(.failure(NSError(domain: "auth", code: 401))); return
        }
        guard (200...299).contains(http.statusCode) else {
            // e.g. 429 rate limit, 5xx — a real failure, not empty data.
            completion(.failure(NSError(domain: "http", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]))); return
        }
        guard let data = data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            completion(.failure(CredError.badFormat)); return
        }
        // Prefer top-level five_hour / seven_day; fall back to limits[].
        var session = parseLimit(obj["five_hour"] as? [String: Any])
        var weeklyAll = parseLimit(obj["seven_day"] as? [String: Any])
        var weeklyScoped = parseLimit(obj["seven_day_sonnet"] as? [String: Any])
            ?? parseLimit(obj["seven_day_opus"] as? [String: Any])
        var scopedName: String? = (obj["seven_day_opus"] != nil && !(obj["seven_day_opus"] is NSNull)) ? "Opus" : "Sonnet"

        if let limits = obj["limits"] as? [[String: Any]] {
            for l in limits {
                let kind = l["kind"] as? String
                let lim = parseLimit(l)
                if kind == "session", session == nil { session = lim }
                if kind == "weekly_all", weeklyAll == nil { weeklyAll = lim }
                if kind == "weekly_scoped" {
                    if weeklyScoped == nil { weeklyScoped = lim }
                    if let scope = l["scope"] as? [String: Any],
                       let model = scope["model"] as? [String: Any],
                       let name = model["display_name"] as? String {
                        scopedName = name
                    }
                }
            }
        }
        // A 200 with neither bucket present is not a usable update — don't render 0%.
        guard session != nil || weeklyAll != nil else {
            completion(.failure(NSError(domain: "parse", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "empty usage response"]))); return
        }
        completion(.success(Usage(session: session, weeklyAll: weeklyAll,
                                  weeklyScoped: weeklyScoped, scopedName: scopedName)))
    }.resume()
}

// MARK: - Formatting

/// Compact relative reset for the menu bar title, e.g. "4h12m", "37m", "2d3h".
func compactReset(_ date: Date?) -> String {
    guard let date = date else { return "—" }
    let delta = date.timeIntervalSince(Date())
    if delta <= 0 { return "now" }
    let hours = Int(delta) / 3600
    let mins = (Int(delta) % 3600) / 60
    if hours >= 24 { return "\(hours / 24)d\(hours % 24)h" }
    if hours > 0 { return "\(hours)h\(mins)m" }
    return "\(mins)m"
}

func fmtReset(_ date: Date?) -> String {
    guard let date = date else { return "—" }
    let now = Date()
    let delta = date.timeIntervalSince(now)
    let df = DateFormatter()
    df.locale = Locale.current
    if delta < 0 { return "resetting…" }
    // Relative + absolute clock time.
    let hours = Int(delta) / 3600
    let mins = (Int(delta) % 3600) / 60
    var rel: String
    if hours >= 24 {
        let days = hours / 24
        let rh = hours % 24
        rel = "\(days)d \(rh)h"
    } else if hours > 0 {
        rel = "\(hours)h \(mins)m"
    } else {
        rel = "\(mins)m"
    }
    if Calendar.current.isDateInToday(date) {
        df.dateFormat = "h:mm a"
    } else {
        df.dateFormat = "EEE h:mm a"
    }
    return "in \(rel) (\(df.string(from: date)))"
}

// MARK: - Notifications

func postNotification(title: String, body: String) {
    func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
    let script = "display notification \"\(esc(body))\" with title \"\(esc(title))\" sound name \"default\""
    _ = runProcess("/usr/bin/osascript", ["-e", script])
}

// MARK: - Tip Jar / Donations

// Where the "tip" buttons link. Replace the URLs with your real donation pages;
// delete a row to hide that button, or leave DONATION_LINKS empty to disable the
// tip jar entirely. Distributed outside the Mac App Store, so these open in the
// browser (StoreKit in-app purchases require App Store distribution).
let DONATION_LINKS: [(label: String, url: String)] = [
    ("☕️  Buy me a coffee", "https://buymeacoffee.com/stavrop"),
]

/// A small, skippable "support this app" window shown on launch until the user
/// opts out. Always reopenable from the menu.
final class TipJarController: NSObject {
    static let suppressKey = "tipjar.dontShowAgain"
    private var window: NSWindow?

    static var isSuppressed: Bool { UserDefaults.standard.bool(forKey: suppressKey) }

    /// Shown automatically at launch unless disabled or the user opted out.
    func showIfNeeded() {
        guard !DONATION_LINKS.isEmpty, !TipJarController.isSuppressed else { return }
        show()
    }

    /// Shown on demand (menu item) regardless of the opt-out flag.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = window { w.center(); w.makeKeyAndOrderFront(nil); return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 20, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Enjoying Usage Monitor for Claude?")
        title.font = .boldSystemFont(ofSize: 16)
        stack.addArrangedSubview(title)

        let body = NSTextField(wrappingLabelWithString:
            "It's free and open source. If it saves you a trip to the terminal, "
            + "a small tip helps keep it maintained. Thank you! 🙏")
        body.alignment = .center
        body.preferredMaxLayoutWidth = 340
        stack.addArrangedSubview(body)

        for (i, link) in DONATION_LINKS.enumerated() {
            let b = NSButton(title: link.label, target: self, action: #selector(openLink(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            b.controlSize = .large
            stack.addArrangedSubview(b)
        }

        let bottom = NSStackView()
        bottom.orientation = .horizontal
        bottom.spacing = 12
        bottom.addArrangedSubview(NSButton(title: "Maybe later", target: self, action: #selector(dismissWindow)))
        bottom.addArrangedSubview(NSButton(title: "Don't show again", target: self, action: #selector(dontShowAgain)))
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(bottom)

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "Support"
        win.contentView = container
        win.isReleasedWhenClosed = false
        win.center()
        window = win
        win.makeKeyAndOrderFront(nil)
    }

    @objc private func openLink(_ sender: NSButton) {
        guard DONATION_LINKS.indices.contains(sender.tag),
              let url = URL(string: DONATION_LINKS[sender.tag].url) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func dismissWindow() { window?.close() }

    @objc private func dontShowAgain() {
        UserDefaults.standard.set(true, forKey: TipJarController.suppressKey)
        window?.close()
    }
}

// MARK: - App

class AppDelegate: NSObject, NSApplicationDelegate {
    let tipJar = TipJarController()
    var statusItem: NSStatusItem!
    var timer: Timer?
    var tickTimer: Timer?
    var lastUsage: Usage?
    var lastUpdated: Date?
    var lastError: String?
    // Tracks the reset time we last alerted for, per bucket, so we fire once
    // per window and re-arm automatically after each reset.
    var alertedFor: [String: Date] = [:]

    func maybeAlert(_ name: String, _ limit: Limit?) {
        guard let l = limit else { return }
        if l.percent < ALERT_THRESHOLD {
            // Below threshold: clear so a later crossing (e.g. unknown reset) re-fires.
            if l.resetsAt == nil { alertedFor[name] = nil }
            return
        }
        let windowKey = l.resetsAt ?? Date.distantFuture
        if alertedFor[name] == windowKey { return } // already alerted this window
        alertedFor[name] = windowKey
        postNotification(
            title: "Claude \(name) usage at \(l.percent)%",
            body: "Resets \(fmtReset(l.resetsAt))"
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Claude …"
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: REFRESH_INTERVAL, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // Lightweight, local: re-render the countdown each minute (no network).
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.renderTitle()
        }
        // Gentle, skippable nudge on launch (until the user opts out).
        tipJar.showIfNeeded()
    }

    func setTitle(_ s: String) {
        DispatchQueue.main.async { self.statusItem.button?.title = s }
    }

    /// Render the menu bar title from the last known usage. Cheap and local — the
    /// countdown ticks down between API polls without any network calls.
    func renderTitle() {
        guard let usage = lastUsage else { return }
        let s = usage.session?.percent ?? 0
        let reset = compactReset(usage.session?.resetsAt)
        setTitle("⛏ \(s)% · \(reset)")
    }

    /// Record a transient failure WITHOUT discarding the last good values: keep
    /// showing the previous percentages and note the error in the dropdown. Only
    /// fall back to a warning glyph if we've never had a successful reading.
    func softError(_ message: String) {
        lastError = message
        if lastUsage == nil { setTitle("Claude ⚠️") }
        rebuildMenu()
    }

    func refresh() {
        let creds: Credentials
        do { creds = try readCredentials() }
        catch {
            softError("No Claude credentials in keychain")
            return
        }
        if creds.isExpired {
            refreshToken(creds) { [weak self] updated in
                if let updated = updated {
                    self?.loadUsage(token: updated.accessToken)
                } else {
                    self?.softError("Token expired — open Claude Code to refresh")
                }
            }
        } else {
            loadUsage(token: creds.accessToken)
        }
    }

    func loadUsage(token: String) {
        fetchUsage(token: token) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let usage):
                self.lastUsage = usage
                self.lastUpdated = Date()
                self.lastError = nil
                // Menu bar: session % + time until the session resets.
                // Weekly stays in the dropdown only.
                self.renderTitle()
                self.maybeAlert("session", usage.session)
                self.maybeAlert("weekly", usage.weeklyAll)
            case .failure(let err):
                let ns = err as NSError
                if ns.code == 401 {
                    // Try a refresh once on hard auth failure.
                    if let creds = try? readCredentials() {
                        refreshToken(creds) { updated in
                            if let updated = updated { self.loadUsage(token: updated.accessToken) }
                            else { self.softError("Auth failed (401)") }
                        }
                        return
                    }
                }
                self.softError("Last refresh failed: \(ns.localizedDescription)")
            }
            self.rebuildMenu()
        }
    }

    func rebuildMenu() {
        DispatchQueue.main.async {
            let menu = NSMenu()
            menu.autoenablesItems = false

            func header(_ title: String) {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }

            if let err = self.lastError {
                header("⚠️ \(err)")
                menu.addItem(.separator())
            }

            if let u = self.lastUsage {
                if let s = u.session {
                    header("Session   \(s.percent)%")
                    let sub = NSMenuItem(title: "   resets \(fmtReset(s.resetsAt))", action: nil, keyEquivalent: "")
                    sub.isEnabled = false
                    menu.addItem(sub)
                }
                menu.addItem(.separator())
                if let w = u.weeklyAll {
                    header("Weekly (all)   \(w.percent)%")
                    let sub = NSMenuItem(title: "   resets \(fmtReset(w.resetsAt))", action: nil, keyEquivalent: "")
                    sub.isEnabled = false
                    menu.addItem(sub)
                }
                if let ws = u.weeklyScoped {
                    let name = u.scopedName ?? "scoped"
                    header("Weekly (\(name))   \(ws.percent)%")
                    let sub = NSMenuItem(title: "   resets \(fmtReset(ws.resetsAt))", action: nil, keyEquivalent: "")
                    sub.isEnabled = false
                    menu.addItem(sub)
                }
                menu.addItem(.separator())
            }

            if let t = self.lastUpdated {
                let df = DateFormatter(); df.dateFormat = "h:mm:ss a"
                header("Updated \(df.string(from: t))")
            }

            let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(self.manualRefresh), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)

            if !DONATION_LINKS.isEmpty {
                let support = NSMenuItem(title: "Support this app…", action: #selector(self.openTipJar), keyEquivalent: "")
                support.target = self
                menu.addItem(support)
            }

            let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quit)

            self.statusItem.menu = menu
        }
    }

    @objc func manualRefresh() { refresh() }

    @objc func openTipJar() { tipJar.show() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
