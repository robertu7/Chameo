import Foundation

struct CaptureProgress: Equatable {
    let capturedDayCount: Int
    let elapsedDayCount: Int
    let missedDates: [Date]

    static func calculate(
        captureDates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CaptureProgress? {
        let capturedDays = Set(captureDates.map(calendar.startOfDay(for:)))
        guard let firstCaptureDay = capturedDays.min(),
              let lastCompletedDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
              let rollingWindowStart = calendar.date(byAdding: .day, value: -29, to: lastCompletedDay) else {
            return nil
        }

        var day = max(firstCaptureDay, rollingWindowStart)
        var completedDays: [Date] = []
        while day <= lastCompletedDay {
            completedDays.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        let capturedDayCount = completedDays.count(where: capturedDays.contains)
        return CaptureProgress(
            capturedDayCount: capturedDayCount,
            elapsedDayCount: completedDays.count,
            missedDates: completedDays.filter { !capturedDays.contains($0) }
        )
    }
}
