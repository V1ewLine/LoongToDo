import Foundation

/// Calendar controls change wall-clock components, never fixed 24-hour offsets.
public enum DateSelection {
    public static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let first = calendar.dateInterval(of: .month, for: date)?.start,
              let start = calendar.date(byAdding: .day, value: -((calendar.component(.weekday, from: first) + 5) % 7), to: first) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    public static func replacingDay(in date: Date, with day: Date, calendar: Calendar = .current) -> Date {
        replacingTime(in: day, hour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date), calendar: calendar)
    }

    public static func replacingTime(in date: Date, hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date,
                      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) ?? date
    }
}
