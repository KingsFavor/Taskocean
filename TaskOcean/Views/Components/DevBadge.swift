import SwiftUI

/// Small "DEV" tag shown only in development builds (nothing in the shipped
/// release). Hovering reveals the running bundle's path, so you can tell exactly
/// which copy — Homebrew vs. Xcode — this window belongs to.
struct DevBadge: View {
    @Environment(\.theme) private var theme

    var body: some View {
        if let text = BuildInfo.badge {
            Text(verbatim: text)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(theme.syncError, in: Capsule())
                .help(Text(verbatim: BuildInfo.bundlePath))
                .accessibilityLabel(Text(verbatim: "Development build"))
        }
    }
}
