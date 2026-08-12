import Foundation

/// Tells the shipped build (Homebrew / Developer ID, Release, in /Applications)
/// apart from a local development build, so two copies running at once are
/// distinguishable. Only development builds surface a marker — end users see nothing.
enum BuildInfo {
    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
    static var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?" }
    static var bundlePath: String { Bundle.main.bundlePath }

    /// True for anything that isn't the installed, shipped release.
    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        // A Release build run from somewhere other than /Applications (e.g. a local
        // archive or DerivedData) is still not the distributed copy.
        return !bundlePath.hasPrefix("/Applications/")
        #endif
    }

    /// Short badge for the UI; nil for the shipped release (so end users see nothing).
    static var badge: String? { isDevelopment ? "DEV" : nil }

    /// Localization key describing the running channel (Settings detail line).
    static var channelKey: String {
        #if DEBUG
        return "build.channel.debug"
        #else
        return isDevelopment ? "build.channel.localRelease" : "build.channel.distribution"
        #endif
    }
}
