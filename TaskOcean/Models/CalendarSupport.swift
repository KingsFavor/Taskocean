import Foundation

/// Calendar utilities. All "day" math uses the user's current calendar/locale
/// so week-start (Sun/Mon) and relative words follow the system (PRD §6.9).
enum CalendarSupport {
    static var calendar: Calendar { Calendar.current }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    static func addingDays(_ n: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: n, to: date) ?? date
    }

    /// Whole-day difference (b - a) ignoring time-of-day.
    static func dayDifference(from a: Date, to b: Date) -> Int {
        let a0 = startOfDay(a), b0 = startOfDay(b)
        return calendar.dateComponents([.day], from: a0, to: b0).day ?? 0
    }

    static func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }
    static func isPast(_ date: Date, relativeTo ref: Date) -> Bool {
        startOfDay(date) < startOfDay(ref)
    }
}

/// Locale-aware date formatting for the header and chips.
enum DayFormatter {
    /// Header line with year, e.g. "2026년 7월 15일" (ko) / "Jul 15, 2026" (en).
    static func headerTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = CalendarSupport.calendar
        df.locale = AppLocale.current
        df.setLocalizedDateFormatFromTemplate("yMMMd")
        return df.string(from: date)
    }

    /// Short weekday, e.g. "화" / "Tue".
    static func weekday(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocale.current
        df.setLocalizedDateFormatFromTemplate("EEE")
        return df.string(from: date)
    }

    /// Relative badge for a due date vs. the currently-viewed day.
    /// Returns a localized "Today/Tomorrow/Yesterday" or a short date.
    static func relativeBadge(due: Date, viewing ref: Date) -> String {
        let diff = CalendarSupport.dayDifference(from: ref, to: due)
        switch diff {
        case 0:  return AppLocale.string("badge.today", "Today")
        case 1:  return AppLocale.string("badge.tomorrow", "Tomorrow")
        case -1: return AppLocale.string("badge.yesterday", "Yesterday")
        default:
            let df = DateFormatter()
            df.locale = AppLocale.current
            df.setLocalizedDateFormatFromTemplate("Md")
            return df.string(from: due)
        }
    }

    /// Compact label for compose date pills: 오늘 / 내일 / "7. 16. (수)" / 없음.
    /// Relative words are anchored to the actual today (not the viewed day).
    static func composeDateLabel(_ date: Date?) -> String {
        guard let date else { return AppLocale.string("date.none", "No date") }
        switch CalendarSupport.dayDifference(from: Date(), to: date) {
        case 0:  return AppLocale.string("badge.today", "Today")
        case 1:  return AppLocale.string("badge.tomorrow", "Tomorrow")
        case -1: return AppLocale.string("badge.yesterday", "Yesterday")
        default:
            let df = DateFormatter()
            df.locale = AppLocale.current
            df.setLocalizedDateFormatFromTemplate("Md EEE")
            return df.string(from: date)
        }
    }

    /// e.g. "7월 11일 · 4일 지남" (ko) / "Jul 11 · 4 days overdue" (en).
    /// Google Tasks' `due` is a *scheduled date*, not a deadline (§8.4.1), so the
    /// wording says the date, not "마감".
    static func overdueDetail(due: Date, today: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocale.current
        df.setLocalizedDateFormatFromTemplate("MMMd")
        let dueStr = df.string(from: due)
        let daysLate = abs(CalendarSupport.dayDifference(from: due, to: today))
        let isKorean = AppLocale.isKorean
        if isKorean {
            return "\(dueStr) · \(daysLate)일 지남"
        } else {
            let late = daysLate == 1 ? "1 day overdue" : "\(daysLate) days overdue"
            return "\(dueStr) · \(late)"
        }
    }
}
