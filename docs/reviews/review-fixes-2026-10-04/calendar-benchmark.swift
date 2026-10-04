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
        DailyCaptureDayIndex(captureDates: captureDates, calendar: calendar)
            .status(for: date, today: today, isAvailable: isAvailable)
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

/// Normalize the history once; month cells only perform day lookups.
struct DailyCaptureDayIndex {
    let calendar: Calendar
    let capturedDays: Set<Date>
    let firstCapturedDay: Date?

    init(captureDates: [Date], calendar: Calendar = .current) {
        self.calendar = calendar
        capturedDays = Set(captureDates.map(calendar.startOfDay(for:)))
        firstCapturedDay = capturedDays.min()
    }

    func status(for date: Date, today: Date = Date(), isAvailable: Bool = true) -> DailyCaptureStatus {
        guard isAvailable else { return .unknown }
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: today)
        guard day <= today else { return .future }
        if capturedDays.contains(day) { return .captured }
        if day == today { return .pendingToday }
        guard let firstCapturedDay, day >= firstCapturedDay else { return .outsideTracking }
        return .missed
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
func elapsed(_ work: () -> Void) -> Double {
    let start = ContinuousClock.now
    work()
    let duration = ContinuousClock.now - start
    return Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}
for count in [365, 1000, 3650, 10000] {
    let captures = (0..<count).map { today.addingTimeInterval(-Double($0) * 86400) }
    var construction: [Double] = [], lookup: [Double] = []
    for _ in 0..<15 {
        var index: DailyCaptureDayIndex!
        construction.append(elapsed { index = DailyCaptureDayIndex(captureDates: captures, calendar: calendar) })
        lookup.append(elapsed { for day in days { if index.status(for: day, today: today) == .captured { sink += 1 } } })
    }
    print("captures=\(count), index construction median ms=\(construction.sorted()[7]), 42 lookups median ms=\(lookup.sorted()[7])")
}
print("sink=\(sink)")
