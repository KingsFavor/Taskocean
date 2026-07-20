import SwiftUI

/// First launch — no connected accounts (design section 06 "빈 상태").
struct FirstRunView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var connecting = false

    var body: some View {
        VStack(spacing: 0) {
            WindowChromeMinimal()
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                Image("TaskOceanLogo")
                    .resizable().scaledToFit()
                    .frame(height: 46)
                    .foregroundStyle(theme.textPrimary)
                    .opacity(0.9)
                VStack(spacing: 7) {
                    Text("firstrun.title")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Text("firstrun.subtitle")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(theme.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 260)
                }
                Button {
                    connecting = true
                    Task { await store.addAccount(); connecting = false }
                } label: {
                    HStack(spacing: 8) {
                        if connecting { ProgressView().controlSize(.small) }
                        Text("firstrun.connect")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Color(hex: "#5B7CA8"), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(connecting)

                Label("firstrun.keychain", systemImage: "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textFaint)
            }
            .padding(.horizontal, 30)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 420)
        .background(theme.window)
    }
}

/// A minimal chrome (just height for the traffic lights) used on modal-ish screens.
/// Doubles as the window move handle (background dragging is disabled app-wide).
struct WindowChromeMinimal: View {
    var body: some View {
        Color.clear.frame(height: 36).background(WindowDragArea())
    }
}
