import AppKit

/// When a Homebrew upgrade replaces the app bundle underneath a still-running copy,
/// relaunch into the freshly installed version automatically.
///
/// Safety:
/// - **Distribution build only.** Never in development — Xcode rebuilds the bundle
///   constantly, which would otherwise trigger an endless self-relaunch loop.
/// - **No polling.** Only re-checks when the app becomes active (e.g. the user
///   returns to TaskOcean after running the update command in Terminal).
/// - **Sandbox-safe & harmless.** Launches a new instance via `NSWorkspace`; only
///   quits the current one if that succeeded. If the launch is blocked or fails,
///   nothing happens and the user simply relaunches manually.
///
/// (If Homebrew quits the app during the upgrade, this never runs — the user just
/// reopens into the new version. This covers the case where the app stays alive.)
@MainActor
final class UpdateRelauncher {
    /// Version baked into the copy that is running right now (captured at launch).
    private let runningVersion = BuildInfo.version
    private var observer: NSObjectProtocol?
    private var relaunching = false

    func start() {
        guard !BuildInfo.isDevelopment else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.relaunchIfBundleUpdated() }
        }
    }

    private func relaunchIfBundleUpdated() {
        guard !relaunching,
              let installed = diskVersion(),
              UpdateChecker.isNewer(installed, than: runningVersion) else { return }
        relaunching = true
        relaunch()
    }

    /// Read the version straight from the on-disk Info.plist — `Bundle.main` caches
    /// its dictionary, so it wouldn't reflect a bundle swapped out from under us.
    private func diskVersion() -> String? {
        let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let version = dict["CFBundleShortVersionString"] as? String else { return nil }
        return version
    }

    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, error in
            Task { @MainActor in
                if error == nil {
                    NSApp.terminate(nil)
                } else {
                    self.relaunching = false   // launch blocked — leave the old copy running
                }
            }
        }
    }
}
