import Foundation

/// Natural-language due-date parsing for quick capture (FR-5.5, ko+en FR-I18N-5).
/// Scans the LAST word of the input for a date keyword; if found, strips it from
/// the title and returns the resolved date. Date-only per API constraint (§8.4.1).
enum NaturalDateParser {
    struct Result {
        let title: String
        let due: Date?
        /// The matched raw token (for the "내일 → 7.16 (수)" chip). Nil if no match.
        let matchedToken: String?
    }

    /// Weekday name → weekday index (1=Sun … 7=Sat, Calendar convention).
    private static let koWeekdays: [String: Int] = [
        "일요일": 1, "월요일": 2, "화요일": 3, "수요일": 4,
        "목요일": 5, "금요일": 6, "토요일": 7,
    ]
    private static let enWeekdays: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7,
        "sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7,
    ]

    static func parse(_ input: String, reference: Date = Date()) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastSpace = trimmed.range(of: " ", options: .backwards) else {
            // Single word — never treat the whole title as a date.
            return Result(title: trimmed, due: nil, matchedToken: nil)
        }
        let token = String(trimmed[lastSpace.upperBound...])
        let rest = String(trimmed[..<lastSpace.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty, let due = resolve(token: token, reference: reference) else {
            return Result(title: trimmed, due: nil, matchedToken: nil)
        }
        return Result(title: rest, due: due, matchedToken: token)
    }

    private static func resolve(token raw: String, reference: Date) -> Date? {
        let cal = CalendarSupport.calendar
        let today = cal.startOfDay(for: reference)
        let token = raw.lowercased()

        switch token {
        case "오늘", "today":     return today
        case "내일", "tomorrow":  return cal.date(byAdding: .day, value: 1, to: today)
        case "모레":               return cal.date(byAdding: .day, value: 2, to: today)
        default: break
        }

        // Weekday names → the NEXT occurrence (강수: this week if still ahead).
        let weekday = koWeekdays[raw] ?? enWeekdays[token]
        if let weekday {
            let current = cal.component(.weekday, from: today)
            var delta = (weekday - current + 7) % 7
            if delta == 0 { delta = 7 }   // "금요일" on a Friday → next Friday
            return cal.date(byAdding: .day, value: delta, to: today)
        }
        return nil
    }

    /// Chip text like "내일 → 7.16 (수)" / "tomorrow → 7.16 (Wed)".
    static func chipText(token: String, due: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocale.current
        df.setLocalizedDateFormatFromTemplate("Md")
        let dateStr = df.string(from: due)
        let wd = DayFormatter.weekday(due)
        return "\(token) → \(dateStr) (\(wd))"
    }
}
