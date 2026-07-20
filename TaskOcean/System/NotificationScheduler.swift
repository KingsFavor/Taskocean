import Foundation
import UserNotifications

/// Local notifications for due tasks (FR-6.2). Google Tasks has no server-side
/// reminders (§8.4.4), so the app schedules its own: one notification per day
/// that has incomplete due tasks, at the user-chosen hour.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    static let enabledKey = "notifications.enabled"
    static let hourKey = "notifications.hour"      // 0–23, default 9

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
    static var hour: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: hourKey)
            return (1...23).contains(v) ? v : 9
        }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Re-plan everything from the current snapshot. Cheap enough to run on
    /// every data change (only future 14 days are scheduled).
    func reschedule(tasks: [TaskItem]) {
        guard Self.isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let cal = CalendarSupport.calendar
        let today = cal.startOfDay(for: Date())
        // Group incomplete, due tasks by day (next 14 days).
        var byDay: [Date: [TaskItem]] = [:]
        for t in tasks where !t.isCompleted && !t.isSubtask {
            guard let due = t.due else { continue }
            let day = cal.startOfDay(for: due)
            let offset = cal.dateComponents([.day], from: today, to: day).day ?? -1
            guard (0...14).contains(offset) else { continue }
            byDay[day, default: []].append(t)
        }

        for (day, items) in byDay {
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = Self.hour
            guard let fireDate = cal.date(from: comps), fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = AppLocale.string("notif.title", "Today's tasks")
            content.body = items.prefix(3).map(\.title).joined(separator: " · ")
                + (items.count > 3 ? " …" : "")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour], from: fireDate),
                repeats: false)
            let id = "taskocean-due-\(Int(day.timeIntervalSince1970))"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
