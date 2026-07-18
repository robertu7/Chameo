import Foundation

enum DailyCaptureStatus: Equatable {
    case captured
    case pendingToday
    case missed
    case future
    case outsideTracking
    case unknown

    var accessibilityDescription: String {
        switch self {
        case .captured:
            return "Captured"
        case .pendingToday:
            return "Not captured yet"
        case .missed:
            return "Missed"
        case .future:
            return "Future"
        case .outsideTracking:
            return "Before tracking began"
        case .unknown:
            return "Status unavailable"
        }
    }
}

enum DailyCaptureHistory {
    static func status(
        for date: Date,
        captureDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current,
        isAvailable: Bool = true
    ) -> DailyCaptureStatus {
        guard isAvailable else {
            return .unknown
        }

        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)

        guard day <= today else {
            return .future
        }

        let capturedDays = Set(captureDates.map(calendar.startOfDay(for:)))
        if capturedDays.contains(day) {
            return .captured
        }

        if day == today {
            return .pendingToday
        }

        guard let firstCapturedDay = capturedDays.min(), day >= firstCapturedDay else {
            return .outsideTracking
        }

        return .missed
    }

    static func calendarDates(
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

    static func isDate(
        _ date: Date,
        inSameMonthAs month: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }
}
