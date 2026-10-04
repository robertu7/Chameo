import Foundation

final class LibraryCalendarSnapshot {
    let history: DailyCaptureDayIndex
    let assetsByDay: [Date: [ChameoAsset]]
    var calendar: Calendar { history.calendar }

    init(assets: [ChameoAsset], calendar: Calendar) {
        history = DailyCaptureDayIndex(captureDates: assets.compactMap(\.createdAt), calendar: calendar)
        assetsByDay = Dictionary(grouping: assets) {
            calendar.startOfDay(for: $0.createdAt ?? .distantPast)
        }.mapValues { $0.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) } }
    }

    static var displayCalendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = L10n.currentLocalization.displayLocale
        calendar.firstWeekday = 2
        return calendar
    }
}
