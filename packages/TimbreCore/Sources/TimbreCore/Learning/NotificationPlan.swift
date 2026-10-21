import Foundation

/// When the daily word-of-the-day notification fires: at the chosen time
/// today if that is still ahead, otherwise tomorrow. Pure, so the schedule
/// is tested without a notification center.
nonisolated public enum NotificationPlan {

    public static func nextFire(hour: Int, minute: Int, after now: Date, calendar: Calendar = .current)
        -> Date
    {
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
