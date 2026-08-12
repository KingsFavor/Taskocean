import AppKit
import Observation
import SwiftUI

/// Quiet "a new version is available" check for the Developer ID / Homebrew build.
///
/// Deliberately unobtrusive (never harms UX):
/// - Read-only outbound HTTPS to the public GitHub Releases API — App Sandbox safe
///   (`network.client` only; no server entitlement).
/// - Checks at most **once per 24h**, and only on launch. No polling timer.
/// - A network failure is silent — it is never surfaced as an error.
/// - The result is cached so a known update reappears across relaunches **without**
///   a network call, and disappears automatically once the running version catches up.
/// - Dismissing the banner (✕) skips that exact version, so it never nags again.
///
/// The app is installed via Homebrew Cask, so we don't self-update: the banner links
/// to the release page and (on hover) shows the `brew upgrade` command.
@MainActor
@Observable
final class UpdateChecker {
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/KingsFavor/Taskocean/releases/latest")!
    /// The full update command — `brew update` first so Homebrew learns about the new
    /// cask version, then the upgrade. This is what the "Copy command" action copies.
    static let brewUpdateCommand = "brew update && brew upgrade --cask taskocean"
    private static let throttle: TimeInterval = 60 * 60 * 24   // once per day

    /// The running app version, e.g. "0.1.0".
    let currentVersion: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"

    /// Newest published version, only when strictly greater than `currentVersion`.
    private(set) var latestVersion: String?
    private(set) var releaseURL: URL?
    private(set) var isChecking = false

    enum CheckResult: Equatable { case idle, upToDate, available(String), failed }
    /// Drives the Settings status label (set by an explicit "Check now").
    private(set) var lastResult: CheckResult = .idle

    private let defaults = UserDefaults.standard
    private enum Key {
        static let enabled = "update.autoCheckEnabled"
        static let lastCheck = "update.lastCheckAt"
        static let skipped = "update.skippedVersion"
        static let cachedVersion = "update.cachedVersion"
        static let cachedURL = "update.cachedURL"
    }

    var autoCheckEnabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// The banner appears only for a real, newer, non-skipped version.
    var isBannerVisible: Bool {
        guard let latest = latestVersion else { return false }
        return defaults.string(forKey: Key.skipped) != latest
    }

    // MARK: Launch

    /// Restore any cached result immediately, then fetch if the daily throttle elapsed.
    func checkOnLaunch() {
        restoreCache()
        guard autoCheckEnabled else { return }
        if let last = defaults.object(forKey: Key.lastCheck) as? Date,
           Date().timeIntervalSince(last) < Self.throttle {
            return   // already checked today — the cache (if any) is enough
        }
        Task { await performCheck(manual: false) }
    }

    // MARK: User actions (Settings / banner)

    /// Explicit "Check now" — ignores the throttle and re-shows a skipped version.
    func manualCheck() {
        defaults.removeObject(forKey: Key.skipped)
        Task { await performCheck(manual: true) }
    }

    /// User-initiated "Check for Updates…" from the app menu. Because the user asked,
    /// we give explicit feedback via a small result alert — this is expected here and
    /// never shown for the automatic (unsolicited) launch check.
    func checkForUpdatesInteractive() {
        guard !isChecking else { return }
        defaults.removeObject(forKey: Key.skipped)   // explicit check re-shows a skipped version
        Task {
            await performCheck(manual: true)
            presentResultAlert()
        }
    }

    private func presentResultAlert() {
        let alert = NSAlert()
        switch lastResult {
        case .available(let v):
            alert.messageText = "\(AppLocale.string("update.alert.availableTitle", "A new version is available")) (\(v))"
            alert.informativeText = "\(AppLocale.string("update.currentVersion", "Version")) \(currentVersion) → \(v)\n\n\(Self.brewUpdateCommand)"
            alert.addButton(withTitle: AppLocale.string("update.copyCommand", "Copy command"))   // default
            alert.addButton(withTitle: AppLocale.string("update.openRelease", "Open release page"))
            alert.addButton(withTitle: AppLocale.string("update.alert.later", "Later"))
            switch alert.runModal() {
            case .alertFirstButtonReturn:  copyUpdateCommand()
            case .alertSecondButtonReturn: openReleasePage()
            default: break
            }
            return
        case .upToDate:
            alert.messageText = AppLocale.string("update.alert.upToDateTitle", "You're up to date")
            alert.informativeText = "\(AppLocale.string("update.currentVersion", "Version")) \(currentVersion)"
        case .failed:
            alert.messageText = AppLocale.string("update.alert.failedTitle", "Couldn't check for updates")
            alert.informativeText = AppLocale.string("update.alert.failedBody", "Please check your connection and try again.")
        case .idle:
            return
        }
        alert.addButton(withTitle: AppLocale.string("action.ok", "OK"))
        alert.runModal()
    }

    /// ✕ on the banner: skip this exact version so it never shows again.
    func dismissBanner() {
        if let latest = latestVersion { defaults.set(latest, forKey: Key.skipped) }
    }

    func openReleasePage() {
        if let url = releaseURL { NSWorkspace.shared.open(url) }
    }

    /// Copy the `brew update && brew upgrade` command to the clipboard.
    func copyUpdateCommand() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(Self.brewUpdateCommand, forType: .string)
    }

    // MARK: Internal

    private func restoreCache() {
        guard let cached = defaults.string(forKey: Key.cachedVersion),
              Self.isNewer(cached, than: currentVersion) else {
            latestVersion = nil; releaseURL = nil
            return
        }
        latestVersion = cached
        releaseURL = defaults.string(forKey: Key.cachedURL).flatMap { URL(string: $0) }
        lastResult = .available(cached)
    }

    private func performCheck(manual: Bool) async {
        isChecking = true
        defer { isChecking = false }
        defaults.set(Date(), forKey: Key.lastCheck)

        do {
            var req = URLRequest(url: Self.latestReleaseAPI, timeoutInterval: 10)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            // GitHub rejects requests without a User-Agent.
            req.setValue("TaskOcean/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                lastResult = .failed
                return
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let tag = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

            if Self.isNewer(tag, than: currentVersion) {
                latestVersion = tag
                releaseURL = URL(string: release.htmlURL)
                lastResult = .available(tag)
                defaults.set(tag, forKey: Key.cachedVersion)
                defaults.set(release.htmlURL, forKey: Key.cachedURL)
            } else {
                latestVersion = nil
                releaseURL = nil
                lastResult = .upToDate
                defaults.removeObject(forKey: Key.cachedVersion)
                defaults.removeObject(forKey: Key.cachedURL)
            }
        } catch {
            // Offline or rate-limited: stay silent. Only the explicit-check label reflects it.
            lastResult = .failed
        }
    }

    /// Numeric dotted-version compare ("0.2.0" > "0.1.9"); missing components = 0.
    static func isNewer(_ candidate: String, than base: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        }
        let a = parts(candidate), b = parts(base)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
