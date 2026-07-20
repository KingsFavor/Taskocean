import SwiftUI

/// A connected Google account. Maps 1:1 to an OAuth session (future).
struct Account: Identifiable, Hashable {
    let id: String
    var displayName: String       // e.g. "업무 계정" / "Work"
    var email: String             // jun@company.com
    var kind: Kind                // workspace vs personal (label only)
    var colorSeed: AccountColor   // accent used across avatars/chips/dots
    var sessionState: SessionState = .active

    enum Kind: String, Hashable {
        case workspace   // Google Workspace
        case personal    // consumer Gmail
    }

    /// Session lifecycle (PRD §8.7). Kept per-account so one expiry never blocks others.
    enum SessionState: Hashable {
        case active
        case refreshing
        case needsReauth   // hard expiry / revoked → non-blocking banner
    }

    /// The single uppercase letter shown inside the avatar.
    var avatarInitial: String {
        String(displayName.first.map(String.init) ?? email.first.map(String.init) ?? "?").uppercased()
    }
}

/// Fixed accent palette seeds. Matches the two design accounts, then cycles for 3+.
enum AccountColor: String, CaseIterable, Hashable {
    case blue    // #5B7CA8  — design "업무 · J"
    case tan     // #B08363  — design "개인 · P"
    case teal
    case violet
    case rose
    case olive

    var accent: Color {
        switch self {
        case .blue:   return Color(hex: "#5B7CA8")
        case .tan:    return Color(hex: "#B08363")
        case .teal:   return Color(hex: "#5E9E97")
        case .violet: return Color(hex: "#8B7BB0")
        case .rose:   return Color(hex: "#B0637E")
        case .olive:  return Color(hex: "#8A9A5B")
        }
    }

    /// A soft tinted background for date/time chips in the account color, per scheme.
    func chipBackground(dark: Bool) -> Color {
        dark ? accent.opacity(0.22) : accent.opacity(0.12)
    }

    func chipForeground(dark: Bool) -> Color {
        dark ? accent.opacity(0.95) : accent
    }

    static func seed(forIndex index: Int) -> AccountColor {
        let all = AccountColor.allCases
        return all[index % all.count]
    }
}
