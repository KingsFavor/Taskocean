import SwiftUI

/// Neutral pill chip (e.g. the "오늘 / Today" relative badge).
struct RelativeChip: View {
    let text: String
    @Environment(\.theme) private var theme
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: theme.chipRadius))
    }
}

/// Task count shown as "완료/전체" (done faint, total emphasized).
struct CompletionCount: View {
    let done: Int
    let total: Int
    var accent: Color? = nil
    var fontSize: CGFloat = 12
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 1) {
            Text("\(done)").foregroundStyle(theme.textFaint)
            Text(verbatim: "/").foregroundStyle(theme.textFaint)
            Text("\(total)").foregroundStyle(accent ?? theme.textMuted)
        }
        .font(.system(size: fontSize, weight: .semibold))
        .help(tooltip)
    }

    private var tooltip: String {
        let d = AppLocale.string("count.done", "Done")
        let t = AppLocale.string("count.total", "Total")
        return "\(d) \(done) · \(t) \(total)"
    }
}

/// Top-level (temporal) section header: "기한 없음 0/3". Optionally collapsible.
/// Ranks ABOVE account sub-headers — a hairline + extra top space set it apart.
struct SectionHeader: View {
    let title: String
    let done: Int
    let total: Int
    var isCollapsed: Bool = false
    var showDivider: Bool = true
    var icon: String? = nil        // e.g. warning glyph for Overdue
    var accent: Color? = nil       // urgency tint for icon + count
    var titleColor: Color? = nil   // tint the title itself (Overdue carries urgency here)
    var onToggle: (() -> Void)? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if showDivider {
                Rectangle().fill(theme.divider).frame(height: 1)
                    .padding(.horizontal, 15)
            }
            Group {
                if let onToggle {
                    Button(action: onToggle) { row }.buttonStyle(.plain)
                } else {
                    row
                }
            }
        }
        .padding(.top, 18)
    }

    private var row: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(accent ?? theme.textSecondary)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(titleColor ?? theme.textPrimary)
            CompletionCount(done: done, total: total, accent: accent, fontSize: 12)
            Spacer(minLength: 0)
            if onToggle != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textMuted)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 12).padding(.bottom, 8)
        .contentShape(Rectangle())
    }
}

/// Per-item sync status indicator (FR-SYNC-8) — subtle, non-blocking.
struct SyncStateBadge: View {
    let state: SyncState
    @Environment(\.theme) private var theme

    var body: some View {
        switch state {
        case .synced:
            EmptyView()
        case .pending:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.syncPending)
                .help(Text("sync.pending"))
        case .conflict:
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.syncError)
                .help(Text("sync.conflict"))
        case .error:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.syncError)
                .help(Text("sync.error"))
        }
    }
}

/// Small subtask-progress meter (design: bar + "2/3").
struct SubtaskProgress: View {
    let done: Int
    let total: Int
    @Environment(\.theme) private var theme
    private let barWidth: CGFloat = 52

    var body: some View {
        // Fixed-size bar (no GeometryReader — that one is greedy and was inflating
        // the card's height when placed in the card's trailing row).
        HStack(spacing: 7) {
            ZStack(alignment: .leading) {
                Capsule().fill(theme.panelStrong)
                    .frame(width: barWidth, height: 5)
                Capsule().fill(theme.textPrimary)
                    .frame(width: barWidth * (total == 0 ? 0 : CGFloat(done) / CGFloat(total)),
                           height: 5)
            }
            .frame(width: barWidth, height: 5)
            Text("\(done)/\(total)")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(theme.textFaint)
                .monospacedDigit()
                .fixedSize()
        }
    }
}

/// Which list a task lives in, as a small capsule tag. Used on every task row
/// (full card / compact row / overdue card / inbox row) so the day reads
/// consistently — the account is the grouping, the list is the tag.
///
/// Width: `.frame(maxWidth:)` alone is a *flexible* frame and would stretch even
/// short names to the cap, making every tag the same width. `.fixedSize()`
/// proposes the ideal (text) width, which the frame then clamps — so short names
/// hug their text and only long ones truncate.
struct ListTag: View {
    let title: String
    var maxWidth: CGFloat = 92
    var fontSize: CGFloat = 10.5
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(theme.textMuted)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .fixedSize()
            .padding(.horizontal, fontSize > 10 ? 7 : 5)
            .padding(.vertical, fontSize > 10 ? 2.5 : 2)
            .background(theme.panel, in: Capsule())
    }
}

