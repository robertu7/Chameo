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
            return L10n.string("Captured")
        case .pendingToday:
            return L10n.string("Not captured yet")
        case .missed:
            return L10n.string("Missed")
        case .future:
            return L10n.string("Future")
        case .outsideTracking:
            return L10n.string("Before tracking began")
        case .unknown:
            return L10n.string("Status unavailable")
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

enum L10n { static func string(_ s: String) -> String { s } }

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
calendar.firstWeekday = 2
let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
let shownMonth = calendar.date(byAdding: .month, value: -1, to: today)!
let days = DailyCaptureHistory.calendarDates(inMonthContaining: shownMonth, calendar: calendar)
var sink = 0
for count in [365, 1000, 3650, 10000] {
    let captures = (0..<count).map { today.addingTimeInterval(-Double($0) * 86400) }
    var samples: [Double] = []
    for _ in 0..<15 {
        let start = ContinuousClock.now
        for date in days {
            if DailyCaptureHistory.status(for: date, captureDates: captures, today: today, calendar: calendar) == .captured { sink += 1 }
        }
        let d = ContinuousClock.now - start
        samples.append(Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15)
    }
    let median = samples.sorted()[samples.count / 2]
    let capturedDays = Set(captures.map(calendar.startOfDay(for:)))
    let firstDay = capturedDays.min()!
    var cachedSamples: [Double] = []
    for _ in 0..<15 {
        let start = ContinuousClock.now
        for date in days {
            let day = calendar.startOfDay(for: date)
            let current = calendar.startOfDay(for: today)
            if day <= current, capturedDays.contains(day) { sink += 1 }
            else if day != current, day >= firstDay { sink += 0 }
        }
        let d = ContinuousClock.now - start
        cachedSamples.append(Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15)
    }
    print("assets=\(count) 42 statuses current_median_ms=\(median) precomputed_median_ms=\(cachedSamples.sorted()[cachedSamples.count / 2])")
}
print("sink=\(sink)")
