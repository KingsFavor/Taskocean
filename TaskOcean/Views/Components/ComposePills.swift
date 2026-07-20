import SwiftUI

/// Button style for options inside custom popovers/dropdowns (list rows, calendar
/// cells): fills the whole frame as the hit area (so you needn't click the glyph)
/// and shows a subtle hover/press background — the pointer feedback native menus
/// get for free. `active` (e.g. the selected row) suppresses the hover fill.
struct HoverOptionStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    var active: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, cornerRadius: cornerRadius, active: active)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        var cornerRadius: CGFloat
        var active: Bool
        @Environment(\.theme) private var theme
        @State private var hovering = false

        var body: some View {
            configuration.label
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .background {
                    if !active && (hovering || configuration.isPressed) {
                        RoundedRectangle(cornerRadius: cornerRadius).fill(theme.panel)
                    }
                }
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.1), value: hovering)
        }
    }
}

/// Tappable badge for the compose target list: account avatar + list name.
/// Clicking the badge opens a dropdown grouped by account (FR-5.x quick add).
/// Shared by the day-view footer and the global quick-capture panel so both
/// change account/list the same way.
///
/// `lockedToAccountID` restricts the dropdown to one account's lists. Editing an
/// existing task passes its account: moving a task across accounts is not a field
/// edit but a recreate + delete (PRD §8.4.5) that mints a new id and drops
/// position / completedAt, so it stays an explicit action in the context menu.
/// Composing a *new* task leaves it nil — every account is a valid target.
struct ComposeListPill: View {
    @Binding var listID: String
    var lockedToAccountID: String? = nil
    var avatarSize: CGFloat = 18
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var showPicker = false

    private var list: TaskList? { store.list(listID) }
    private var account: Account? { list.flatMap { store.account($0.accountID) } }

    var body: some View {
        Button {
            showPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                if let account { AccountAvatar(account: account, size: avatarSize) }
                Text(list?.title ?? "")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 3)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .help(Text("compose.list.help"))
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            picker
        }
    }

    private var pickerAccounts: [Account] {
        guard let id = lockedToAccountID else { return store.accounts }
        return store.accounts.filter { $0.id == id }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(pickerAccounts) { acc in
                Text(acc.displayName)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(theme.textMuted)
                    .padding(.horizontal, 11).padding(.top, 9).padding(.bottom, 3)
                ForEach(store.lists.filter { $0.accountID == acc.id }) { l in
                    Button {
                        listID = l.id
                        showPicker = false
                    } label: {
                        HStack(spacing: 8) {
                            AccountAvatar(account: acc, size: 16)
                            Text(l.title)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 14)
                            if l.id == listID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(HoverOptionStyle(cornerRadius: 7))
                    .padding(.horizontal, 5)
                }
            }
        }
        .padding(.vertical, 5)
        .frame(minWidth: 210)
        .background(theme.window)
    }
}

/// Tappable badge for the compose due-date: shows 오늘 / 내일 / a short date /
/// "없음", and opens a popover with quick 오늘·내일 chips, a graphical calendar
/// picker, and a "없음" (Inbox) option. Due is date-only (PRD §8.4.1).
struct ComposeDatePill: View {
    @Binding var due: Date?
    @Environment(\.theme) private var theme
    @State private var showPicker = false
    @State private var working = Date()

    var body: some View {
        Button {
            working = due ?? CalendarSupport.startOfDay(Date())
            showPicker.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: due == nil ? "calendar.badge.minus" : "calendar")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(due == nil ? theme.iconMuted : Color(hex: "#B08363"))
                Text(DayFormatter.composeDateLabel(due))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(due == nil ? theme.textMuted : theme.textSecondary)
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .help(Text("compose.due.help"))
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            picker
        }
    }

    private var today: Date { CalendarSupport.startOfDay(Date()) }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                PopoverChip(titleKey: "badge.today", selected: isChosen(today)) {
                    due = today; showPicker = false
                }
                PopoverChip(titleKey: "badge.tomorrow", selected: isChosen(tomorrow)) {
                    due = tomorrow; showPicker = false
                }
                Spacer(minLength: 0)
                PopoverChip(titleKey: "date.none", muted: true, selected: due == nil) {
                    due = nil; showPicker = false
                }
            }
            MonthCalendar(selection: $working, accent: Color(hex: "#B08363")) { picked in
                due = CalendarSupport.startOfDay(picked)
                showPicker = false
            }
        }
        .padding(16)
        .frame(width: 296)
        .background(theme.window)
    }

    private var tomorrow: Date { CalendarSupport.addingDays(1, to: today) }
    private func isChosen(_ date: Date) -> Bool {
        due.map { CalendarSupport.isSameDay($0, date) } ?? false
    }
}

/// A small pill option (오늘 / 내일 / 없음) with hover feedback.
private struct PopoverChip: View {
    let titleKey: LocalizedStringKey
    var muted: Bool = false
    var selected: Bool = false
    let action: () -> Void
    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(titleKey)
                .font(.system(size: 11.5, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? theme.checkboxFillGlyph
                                 : (muted ? theme.textMuted : theme.textSecondary))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.1), value: hovering)
    }

    private var background: Color {
        if selected { return theme.checkboxFill }
        return hovering ? theme.panelStrong : theme.panel
    }
}

/// Custom month calendar sized for readability — the native `.graphical`
/// DatePicker keeps a fixed compact cell size that won't scale with its frame,
/// so we draw our own grid in the app palette (accent = brown due tint).
struct MonthCalendar: View {
    @Binding var selection: Date
    var accent: Color
    var onPick: (Date) -> Void
    @Environment(\.theme) private var theme
    @State private var visibleMonth = Date()
    @State private var loaded = false

    private var cal: Calendar { CalendarSupport.calendar }
    private let cell = CGSize(width: 38, height: 34)

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayRow
            grid
        }
        .onAppear {
            if !loaded { visibleMonth = startOfMonth(selection); loaded = true }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(monthTitle(visibleMonth))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Spacer(minLength: 0)
            navButton("chevron.left") { shiftMonth(-1) }
            navButton("chevron.right") { shiftMonth(1) }
        }
        .padding(.bottom, 2)
    }

    private func navButton(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 26, height: 26)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                Text(sym)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textMuted)
                    .frame(width: cell.width)
            }
        }
    }

    private var grid: some View {
        let days = monthGrid(visibleMonth)
        return VStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { wd in
                        dayCell(days[week * 7 + wd])
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = cal.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = cal.isDate(day, inSameDayAs: selection)
        let isToday = cal.isDateInToday(day)
        return Button {
            selection = day
            onPick(day)
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white
                                 : (inMonth ? theme.textPrimary : theme.textFaint))
                .frame(width: cell.width, height: cell.height)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9).fill(accent)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 9).stroke(accent.opacity(0.55), lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(HoverOptionStyle(cornerRadius: 9, active: isSelected))
    }

    // MARK: Date math
    private func startOfMonth(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func shiftMonth(_ n: Int) {
        withAnimation(.snappy(duration: 0.15)) {
            visibleMonth = cal.date(byAdding: .month, value: n, to: visibleMonth) ?? visibleMonth
        }
    }

    /// 6×7 grid starting on the calendar's first weekday.
    private func monthGrid(_ month: Date) -> [Date] {
        let first = startOfMonth(month)
        let weekday = cal.component(.weekday, from: first)
        let lead = (weekday - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -lead, to: first) ?? first
        return (0..<42).map { cal.date(byAdding: .day, value: $0, to: start) ?? start }
    }

    private var weekdaySymbols: [String] {
        let syms = cal.veryShortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(syms[start...] + syms[..<start])
    }

    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocale.current
        df.calendar = cal
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df.string(from: date)
    }
}
