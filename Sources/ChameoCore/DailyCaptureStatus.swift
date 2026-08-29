import Foundation

public enum DailyCaptureStatus: Equatable, Sendable {
    case captured
    case pendingToday
    case missed
    case future
    case outsideTracking
    case unknown
}

public enum DailyCaptureHistory {
    public static func status(
        for date: Date,
        captureDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current,
        isAvailable: Bool = true
    ) -> DailyCaptureStatus {
        guard isAvailable else { return .unknown }

        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)
        guard day <= today else { return .future }

        let capturedDays = Set(captureDates.map(calendar.startOfDay(for:)))
        if capturedDays.contains(day) { return .captured }
        if day == today { return .pendingToday }
        guard let firstCapturedDay = capturedDays.min(), day >= firstCapturedDay else {
            return .outsideTracking
        }
        return .missed
    }

    public static func calendarDates(
        inMonthContaining date: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }
        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingDayCount = (weekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -leadingDayCount,
            to: firstDay
        ) else {
            return []
        }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    public static func isDate(
        _ date: Date,
        inSameMonthAs month: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }
}
