import SwiftUI

/// The small circular account badge (design: J / P). Carries the account color.
struct AccountAvatar: View {
    let account: Account
    var size: CGFloat = 18
    var faded: Bool = false
    var ringColor: Color? = nil   // white ring when overlapped on a stack

    var body: some View {
        Text(account.avatarInitial)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(account.colorSeed.accent, in: Circle())
            .overlay {
                if let ringColor {
                    Circle().stroke(ringColor, lineWidth: 1.5)
                }
            }
            .opacity(faded ? 0.4 : 1)
            .help("\(account.displayName) · \(account.email)")
    }
}

/// Subtle per-account sub-header inside a day section (multi-account full view).
/// Marks the boundary within which drag-reorder is possible; collapsible.
struct AccountSubHeader: View {
    let account: Account
    var done: Int = 0
    var total: Int = 0
    var isCollapsed: Bool = false
    var onToggle: (() -> Void)? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        Button { onToggle?() } label: {
            HStack(spacing: 7) {
                AccountAvatar(account: account, size: 16)
                Text(account.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(account.colorSeed.chipForeground(dark: theme.isDark))
                    .textCase(nil)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if total > 0 {
                    CompletionCount(done: done, total: total, fontSize: 11)
                }
                Spacer(minLength: 0)
                if onToggle != nil {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(theme.textFaint)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 14).padding(.bottom, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Overlapping avatar stack used in the filter row.
struct AccountAvatarStack: View {
    let accounts: [Account]
    var size: CGFloat = 22
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: -8) {
            ForEach(accounts) { acc in
                AccountAvatar(account: acc, size: size, ringColor: theme.window)
            }
        }
    }
}
