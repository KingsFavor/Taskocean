import SwiftUI

/// Month-grid density heatmap (design section 05, PRD FR-DAY-6~9).
/// Density = incomplete task count per day. Click a cell → jump to that day.
/// NOTE: threshold buckets are provisional (dev_note: 미해결 히트맵 임계값).
struct HeatmapView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var monthAnchor = CalendarSupport.startOfDay(Date())

    private var calendar: Calendar { CalendarSupport.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).foregroundStyle(theme.textSecondary)
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain).foregroundStyle(theme.textSecondary)
            }

            // Weekday header (locale week-start, PRD FR-DAY-9)
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(theme.textFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            let cell: CGFloat = 30
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        cellView(date, size: cell)
                    } else {
                        Color.clear.frame(height: cell)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("heatmap.less").font(.system(size: 10, weight: .medium)).foregroundStyle(theme.textFaint)
                ForEach(0..<4) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(densityColor(level: level))
                        .frame(width: 12, height: 12)
                }
                Text("heatmap.more").font(.system(size: 10, weight: .medium)).foregroundStyle(theme.textFaint)
                Spacer()
                Text("heatmap.clickToJump").font(.system(size: 10, weight: .medium)).foregroundStyle(theme.textMuted)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(theme.window)
    }

    private func cellView(_ date: Date, size: CGFloat) -> some View {
        let count = store.incompleteCount(on: date)
        let isToday = CalendarSupport.isToday(date)
        let isSelected = CalendarSupport.isSameDay(date, store.selectedDay)
        return Button {
            store.select(day: date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundStyle(count >= 3 ? .white : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: size)
                .background(densityColor(level: bucket(count)), in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? theme.textPrimary : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .help("\(count)")
    }

    // Provisional 4-bucket thresholds.
    private func bucket(_ count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2...3: return 2
        default: return 3
        }
    }

    private func densityColor(level: Int) -> Color {
        let base = Color(hex: "#5B7CA8")
        switch level {
        case 0: return theme.panel
        case 1: return base.opacity(0.32)
        case 2: return base.opacity(0.62)
        default: return base
        }
    }

    // MARK: Month math
    private var monthTitle: String {
        let df = DateFormatter(); df.locale = AppLocale.current
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df.string(from: monthAnchor)
    }

    private var weekdaySymbols: [String] {
        let df = DateFormatter(); df.locale = AppLocale.current
        let symbols = df.shortWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Days of the anchored month, front-padded with nils to align week-start.
    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstDay = interval.start
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<daysInMonth {
            cells.append(calendar.date(byAdding: .day, value: d, to: firstDay))
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }
}
